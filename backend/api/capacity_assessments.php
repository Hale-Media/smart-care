<?php
declare(strict_types=1);

/**
 * /api/capacity_assessments.php — Smart Care
 *
 * GET    ?resident_id=1                      -> active assessments per decision
 * GET    ?resident_id=1&decision=X&history=1 -> version history for a decision
 * POST   {resident_id, decision, has_capacity, ...}  -> create
 * PUT    ?id=5 {has_capacity, ...}            -> re-assess (creates new version)
 * DELETE ?id=5                                -> soft delete
 */

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/lib/AuditedRepository.php';

header('Content-Type: application/json');

$jwt = require_auth();
$pdo = db();

function nowStr(): string
{
    return (new DateTimeImmutable('now', new DateTimeZone('UTC')))->format('Y-m-d H:i:s');
}

function input(): array
{
    return json_input();
}

function requireResidentInHome(PDO $pdo, int $residentId, int $homeId): void
{
    $stmt = $pdo->prepare('SELECT 1 FROM residents WHERE id = ? AND home_id = ? AND active = 1');
    $stmt->execute([$residentId, $homeId]);
    if (!$stmt->fetchColumn()) {
        respond(['error' => 'resident not found in this home'], 404);
    }
}

function requireOwnedAssessment(PDO $pdo, int $id, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT ca.* FROM capacity_assessments ca
         JOIN residents r ON r.id = ca.resident_id
         WHERE ca.id = ? AND r.home_id = ? AND ca.deleted_at IS NULL'
    );
    $stmt->execute([$id, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'capacity assessment not found'], 404);
    }
    return $row;
}

try {
    $staffId = (int) $jwt['sub'];
    $homeId  = (int) $jwt['home'];

    match ($_SERVER['REQUEST_METHOD']) {
        'GET'          => handleGet($pdo, $homeId),
        'POST'         => handleCreate($pdo, $staffId, $homeId),
        'PUT', 'PATCH' => handleReassess($pdo, $staffId, $homeId),
        'DELETE'       => handleDelete($pdo, $staffId, $homeId),
        default        => respond(['error' => 'Method not allowed'], 405),
    };
} catch (Throwable $e) {
    respond(['error' => 'Server error', 'detail' => $e->getMessage()], 500);
}

function handleGet(PDO $pdo, int $homeId): never
{
    $residentId = (int) ($_GET['resident_id'] ?? 0);
    if ($residentId <= 0) {
        respond(['error' => 'resident_id is required'], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    if (!empty($_GET['history'])) {
        $decision = trim((string) ($_GET['decision'] ?? ''));
        if ($decision === '') {
            respond(['error' => 'decision is required for history'], 422);
        }
        $stmt = $pdo->prepare(
            'SELECT * FROM capacity_assessments
             WHERE resident_id = ? AND decision = ? AND deleted_at IS NULL
             ORDER BY version_no DESC'
        );
        $stmt->execute([$residentId, $decision]);
        respond(['history' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    $stmt = $pdo->prepare(
        "SELECT * FROM capacity_assessments
         WHERE resident_id = ? AND status = 'active' AND deleted_at IS NULL
         ORDER BY decision"
    );
    $stmt->execute([$residentId]);
    respond(['assessments' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(PDO $pdo, int $staffId, int $homeId): never
{
    $in         = input();
    $residentId = (int) ($in['resident_id'] ?? 0);
    $decision   = trim((string) ($in['decision'] ?? ''));

    $errors = [];
    if ($residentId <= 0)  $errors[] = 'resident_id is required';
    if ($decision === '')  $errors[] = 'decision is required';
    if (!isset($in['has_capacity'])) $errors[] = 'has_capacity is required';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    $stmt = $pdo->prepare(
        'INSERT INTO capacity_assessments
         (home_id, resident_id, decision, has_capacity, assessment_summary,
          best_interests, assessed_by, review_due, version_no, status, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)'
    );
    $stmt->execute([
        $homeId,
        $residentId,
        $decision,
        $in['has_capacity'] ? 1 : 0,
        trim((string) ($in['assessment_summary'] ?? '')) ?: null,
        trim((string) ($in['best_interests'] ?? '')) ?: null,
        $staffId,
        $in['review_due'] ?? null,
        'active',
        nowStr(),
    ]);
    $id = (int) $pdo->lastInsertId();
    respond(['id' => $id], 201);
}

function handleReassess(PDO $pdo, int $staffId, int $homeId): never
{
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    $old = requireOwnedAssessment($pdo, $id, $homeId);
    if ($old['status'] !== 'active') {
        respond(['error' => 'only the active version can be re-assessed'], 409);
    }
    $in = input();

    $pdo->beginTransaction();
    try {
        $pdo->prepare("UPDATE capacity_assessments SET status = 'superseded' WHERE id = ?")
            ->execute([$id]);

        $stmt = $pdo->prepare(
            'INSERT INTO capacity_assessments
             (home_id, resident_id, decision, has_capacity, assessment_summary,
              best_interests, assessed_by, review_due, version_no, status, supersedes_id, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        );
        $stmt->execute([
            (int) $old['home_id'],
            (int) $old['resident_id'],
            $old['decision'],
            isset($in['has_capacity']) ? ($in['has_capacity'] ? 1 : 0) : (int) $old['has_capacity'],
            array_key_exists('assessment_summary', $in)
                ? (trim((string) $in['assessment_summary']) ?: null)
                : $old['assessment_summary'],
            array_key_exists('best_interests', $in)
                ? (trim((string) $in['best_interests']) ?: null)
                : $old['best_interests'],
            $staffId,
            array_key_exists('review_due', $in) ? $in['review_due'] : $old['review_due'],
            (int) $old['version_no'] + 1,
            'active',
            $id,
            nowStr(),
        ]);
        $newId = (int) $pdo->lastInsertId();
        $pdo->commit();
        respond(['id' => $newId, 'superseded' => $id]);
    } catch (Throwable $e) {
        $pdo->rollBack();
        throw $e;
    }
}

function handleDelete(PDO $pdo, int $staffId, int $homeId): never
{
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedAssessment($pdo, $id, $homeId);
    $pdo->prepare('UPDATE capacity_assessments SET deleted_at = ?, deleted_by = ? WHERE id = ?')
        ->execute([nowStr(), $staffId, $id]);
    respond(['deleted' => $id]);
}
