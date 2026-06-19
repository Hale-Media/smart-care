<?php
declare(strict_types=1);

/**
 * /api/safeguarding.php — Smart Care
 *
 * GET    ?resident_id=1           -> concerns for a resident
 * POST   {category, description, resident_id}  -> raise concern
 * PUT    ?id=5&action=review|refer|no_referral|close {...}  -> action on concern
 * DELETE ?id=5                    -> soft delete
 */

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/lib/AuditedRepository.php';

header('Content-Type: application/json');

$jwt = require_auth();
$pdo = db();

const SG_CATEGORIES = [
    'physical', 'psychological', 'financial', 'neglect', 'sexual',
    'discriminatory', 'organisational', 'domestic', 'modern_slavery', 'self_neglect',
];
const SG_STATUSES = ['raised', 'under_review', 'referred', 'no_referral', 'closed'];
const SG_ACTIONS  = ['review', 'refer', 'no_referral', 'close'];

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

function requireOwnedConcern(PDO $pdo, int $id, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT sg.* FROM safeguarding_concerns sg
         LEFT JOIN residents r ON r.id = sg.resident_id
         WHERE sg.id = ?
           AND (sg.home_id = ? OR r.home_id = ?)
           AND sg.deleted_at IS NULL'
    );
    $stmt->execute([$id, $homeId, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'safeguarding concern not found'], 404);
    }
    return $row;
}

try {
    $staffId = (int) $jwt['sub'];
    $homeId  = (int) $jwt['home'];

    match ($_SERVER['REQUEST_METHOD']) {
        'GET'          => handleGet($pdo, $homeId),
        'POST'         => handleCreate($pdo, $staffId, $homeId),
        'PUT', 'PATCH' => handleAction($pdo, $staffId, $homeId),
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

    $stmt = $pdo->prepare(
        'SELECT sg.*, CONCAT(s.first_name, " ", s.last_name) AS raised_by_name
         FROM safeguarding_concerns sg
         LEFT JOIN staff s ON s.id = sg.raised_by
         WHERE sg.resident_id = ? AND sg.deleted_at IS NULL
         ORDER BY sg.raised_at DESC'
    );
    $stmt->execute([$residentId]);
    respond(['concerns' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(PDO $pdo, int $staffId, int $homeId): never
{
    $in          = input();
    $residentId  = (int) ($in['resident_id'] ?? 0);
    $category    = (string) ($in['category'] ?? '');
    $description = trim((string) ($in['description'] ?? ''));

    $errors = [];
    if ($residentId <= 0)                              $errors[] = 'resident_id is required';
    if (!in_array($category, SG_CATEGORIES, true))    $errors[] = 'invalid category';
    if ($description === '')                           $errors[] = 'description is required';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    $stmt = $pdo->prepare(
        'INSERT INTO safeguarding_concerns
         (home_id, resident_id, category, description, status, raised_by, raised_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $homeId,
        $residentId,
        $category,
        $description,
        'raised',
        $staffId,
        nowStr(),
    ]);
    $id = (int) $pdo->lastInsertId();
    respond(['id' => $id], 201);
}

function handleAction(PDO $pdo, int $staffId, int $homeId): never
{
    $id     = (int) ($_GET['id'] ?? 0);
    $action = (string) ($_GET['action'] ?? '');
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    if (!in_array($action, SG_ACTIONS, true)) {
        respond(['error' => 'invalid action'], 422);
    }
    $concern = requireOwnedConcern($pdo, $id, $homeId);
    if ($concern['status'] === 'closed') {
        respond(['error' => 'concern is already closed'], 409);
    }
    $in = input();

    $fields = [];
    $params = [];

    switch ($action) {
        case 'review':
            $fields[] = "status = 'under_review'";
            if (!empty($in['manager_review'])) {
                $fields[] = 'manager_review = ?';
                $params[] = trim((string) $in['manager_review']);
            }
            break;
        case 'refer':
            $fields[] = "status = 'referred'";
            $fields[] = 'la_referred = 1';
            $fields[] = 'referred_at = ?';
            $params[] = nowStr();
            if (!empty($in['la_reference'])) {
                $fields[] = 'la_reference = ?';
                $params[] = trim((string) $in['la_reference']);
            }
            if (!empty($in['cqc_notified'])) {
                $fields[] = 'cqc_notified = 1';
            }
            break;
        case 'no_referral':
            $fields[] = "status = 'no_referral'";
            if (!empty($in['manager_review'])) {
                $fields[] = 'manager_review = ?';
                $params[] = trim((string) $in['manager_review']);
            }
            break;
        case 'close':
            $fields[] = "status = 'closed'";
            $fields[] = 'closed_at = ?';
            $params[] = nowStr();
            if (!empty($in['outcome'])) {
                $fields[] = 'outcome = ?';
                $params[] = trim((string) $in['outcome']);
            }
            break;
    }

    if (empty($fields)) {
        respond(['error' => 'no fields to update'], 422);
    }
    $params[] = $id;
    $pdo->prepare('UPDATE safeguarding_concerns SET ' . implode(', ', $fields) . ' WHERE id = ?')
        ->execute($params);
    respond(['updated' => $id]);
}

function handleDelete(PDO $pdo, int $staffId, int $homeId): never
{
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedConcern($pdo, $id, $homeId);
    $pdo->prepare('UPDATE safeguarding_concerns SET deleted_at = ?, deleted_by = ? WHERE id = ?')
        ->execute([nowStr(), $staffId, $id]);
    respond(['deleted' => $id]);
}
