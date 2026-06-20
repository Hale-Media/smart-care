<?php
declare(strict_types=1);

/**
 * /api/capacity_assessments.php — Smart Care
 *
 * GET    ?resident_id=1                      -> active assessments per decision
 * GET    ?resident_id=1&decision=X&history=1 -> version history for a decision
 * POST   {resident_id, decision, has_capacity, ...}  -> create  (senior+ only)
 * PUT    ?id=5 {has_capacity, ...}            -> re-assess (new version)  (senior+ only)
 * DELETE ?id=5                                -> soft delete  (senior+ only)
 */

require_once __DIR__ . '/config.php';

header('Content-Type: application/json');

$jwt     = require_auth();
$pdo     = db();
$staffId = (int) $jwt['staff_id'];
$homeId  = (int) $jwt['home_id'];
$repo    = new AuditedRepository($pdo, $staffId, $homeId, $_SERVER['REMOTE_ADDR'] ?? null);

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
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'          => handleGet($pdo, $homeId),
        'POST'         => handleCreate($repo, $pdo, $staffId, $homeId, $jwt),
        'PUT', 'PATCH' => handleReassess($repo, $pdo, $staffId, $homeId, $jwt),
        'DELETE'       => handleDelete($repo, $pdo, $homeId, $jwt),
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

function handleCreate(AuditedRepository $repo, PDO $pdo, int $staffId, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $in         = input();
    $residentId = (int) ($in['resident_id'] ?? 0);
    $decision   = trim((string) ($in['decision'] ?? ''));

    $errors = [];
    if ($residentId <= 0)          $errors[] = 'resident_id is required';
    if ($decision === '')          $errors[] = 'decision is required';
    if (!isset($in['has_capacity'])) $errors[] = 'has_capacity is required';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    $id = $repo->insert('capacity_assessments', [
        'home_id'            => $homeId,
        'resident_id'        => $residentId,
        'decision'           => $decision,
        'has_capacity'       => $in['has_capacity'] ? 1 : 0,
        'assessment_summary' => trim((string) ($in['assessment_summary'] ?? '')) ?: null,
        'best_interests'     => trim((string) ($in['best_interests'] ?? '')) ?: null,
        'assessed_by'        => $staffId,
        'review_due'         => $in['review_due'] ?? null,
        'version_no'         => 1,
        'status'             => 'active',
        'created_at'         => nowStr(),
    ], 'capacity_assessment');

    respond(['id' => $id], 201);
}

function handleReassess(AuditedRepository $repo, PDO $pdo, int $staffId, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    $old = requireOwnedAssessment($pdo, $id, $homeId);
    if ($old['status'] !== 'active') {
        respond(['error' => 'only the active version can be re-assessed'], 409);
    }
    $in = input();

    $newId = $repo->supersede(
        'capacity_assessments',
        'capacity_assessment',
        $id,
        [
            'home_id'            => (int) $old['home_id'],
            'resident_id'        => (int) $old['resident_id'],
            'decision'           => $old['decision'],
            'has_capacity'       => isset($in['has_capacity'])
                                        ? ($in['has_capacity'] ? 1 : 0)
                                        : (int) $old['has_capacity'],
            'assessment_summary' => array_key_exists('assessment_summary', $in)
                                        ? (trim((string) $in['assessment_summary']) ?: null)
                                        : $old['assessment_summary'],
            'best_interests'     => array_key_exists('best_interests', $in)
                                        ? (trim((string) $in['best_interests']) ?: null)
                                        : $old['best_interests'],
            'assessed_by'        => $staffId,
            'review_due'         => array_key_exists('review_due', $in) ? $in['review_due'] : $old['review_due'],
            'created_at'         => nowStr(),
        ]
    );

    respond(['id' => $newId, 'superseded' => $id]);
}

function handleDelete(AuditedRepository $repo, PDO $pdo, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedAssessment($pdo, $id, $homeId);
    $repo->softDelete('capacity_assessments', $id, 'capacity_assessment');
    respond(['deleted' => $id]);
}
