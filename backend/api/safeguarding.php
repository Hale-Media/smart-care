<?php
declare(strict_types=1);

/**
 * /api/safeguarding.php — Smart Care
 *
 * GET    ?resident_id=1           -> concerns for a resident
 * POST   {category, description, resident_id}  -> raise concern  (any authenticated staff)
 * PUT    ?id=5&action=review|refer|no_referral|close {...}  -> action  (senior+ only)
 * DELETE ?id=5                    -> soft delete  (senior+ only)
 */

require_once __DIR__ . '/config.php';

header('Content-Type: application/json');

$jwt     = require_auth();
$pdo     = db();
$staffId = (int) $jwt['staff_id'];
$homeId  = (int) $jwt['home_id'];
$repo    = new AuditedRepository($pdo, $staffId, $homeId, $_SERVER['REMOTE_ADDR'] ?? null);

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
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'          => handleGet($pdo, $homeId),
        'POST'         => handleCreate($repo, $pdo, $staffId, $homeId),
        'PUT', 'PATCH' => handleAction($repo, $pdo, $homeId, $jwt),
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

    $stmt = $pdo->prepare(
        'SELECT sg.*, s.name AS raised_by_name
         FROM safeguarding_concerns sg
         LEFT JOIN staff s ON s.id = sg.raised_by
         WHERE sg.resident_id = ? AND sg.deleted_at IS NULL
         ORDER BY sg.raised_at DESC'
    );
    $stmt->execute([$residentId]);
    respond(['concerns' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(AuditedRepository $repo, PDO $pdo, int $staffId, int $homeId): never
{
    // Intentionally open to all authenticated staff — any carer can raise a concern.
    $in          = input();
    $residentId  = (int) ($in['resident_id'] ?? 0);
    $category    = (string) ($in['category'] ?? '');
    $description = trim((string) ($in['description'] ?? ''));

    $errors = [];
    if ($residentId <= 0)                           $errors[] = 'resident_id is required';
    if (!in_array($category, SG_CATEGORIES, true))  $errors[] = 'invalid category';
    if ($description === '')                         $errors[] = 'description is required';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    $id = $repo->insert('safeguarding_concerns', [
        'home_id'     => $homeId,
        'resident_id' => $residentId,
        'category'    => $category,
        'description' => $description,
        'status'      => 'raised',
        'raised_by'   => $staffId,
        'raised_at'   => nowStr(),
    ], 'safeguarding_concern');

    respond(['id' => $id], 201);
}

function handleAction(AuditedRepository $repo, PDO $pdo, int $homeId, array $jwt): never
{
    requireSenior($jwt);

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
    $in   = input();
    $data = [];

    switch ($action) {
        case 'review':
            $data['status'] = 'under_review';
            if (!empty($in['manager_review'])) {
                $data['manager_review'] = trim((string) $in['manager_review']);
            }
            break;
        case 'refer':
            $data['status']      = 'referred';
            $data['la_referred'] = 1;
            $data['referred_at'] = nowStr();
            if (!empty($in['la_reference'])) {
                $data['la_reference'] = trim((string) $in['la_reference']);
            }
            if (!empty($in['cqc_notified'])) {
                $data['cqc_notified'] = 1;
            }
            break;
        case 'no_referral':
            $data['status'] = 'no_referral';
            if (!empty($in['manager_review'])) {
                $data['manager_review'] = trim((string) $in['manager_review']);
            }
            break;
        case 'close':
            $data['status']    = 'closed';
            $data['closed_at'] = nowStr();
            if (!empty($in['outcome'])) {
                $data['outcome'] = trim((string) $in['outcome']);
            }
            break;
    }

    if (empty($data)) {
        respond(['error' => 'no fields to update'], 422);
    }

    $repo->update('safeguarding_concerns', $id, $data, 'safeguarding_concern');
    respond(['updated' => $id]);
}

function handleDelete(AuditedRepository $repo, PDO $pdo, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedConcern($pdo, $id, $homeId);
    $repo->softDelete('safeguarding_concerns', $id, 'safeguarding_concern');
    respond(['deleted' => $id]);
}
