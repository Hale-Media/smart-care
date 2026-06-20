<?php
declare(strict_types=1);

/**
 * /api/advance_decisions.php — Smart Care
 *
 * GET    ?resident_id=1  -> all advance decisions for a resident
 * POST   {resident_id, type, ...}  -> create  (senior+ only)
 * PUT    ?id=5 {...}     -> update             (senior+ only)
 * DELETE ?id=5           -> soft delete        (senior+ only)
 */

require_once __DIR__ . '/config.php';

header('Content-Type: application/json');

$jwt     = require_auth();
$pdo     = db();
$staffId = (int) $jwt['staff_id'];
$homeId  = (int) $jwt['home_id'];
$repo    = new AuditedRepository($pdo, $staffId, $homeId, $_SERVER['REMOTE_ADDR'] ?? null);

const AD_TYPES = ['dnacpr', 'respect', 'adrt'];

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

function requireOwnedAd(PDO $pdo, int $id, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT ad.* FROM advance_decisions ad
         JOIN residents r ON r.id = ad.resident_id
         WHERE ad.id = ? AND r.home_id = ? AND ad.deleted_at IS NULL'
    );
    $stmt->execute([$id, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'advance decision not found'], 404);
    }
    return $row;
}

try {
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'          => handleGet($pdo, $homeId),
        'POST'         => handleCreate($repo, $pdo, $staffId, $homeId, $jwt),
        'PUT', 'PATCH' => handleUpdate($repo, $pdo, $homeId, $jwt),
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
        'SELECT * FROM advance_decisions
         WHERE resident_id = ? AND deleted_at IS NULL
         ORDER BY type, created_at DESC'
    );
    $stmt->execute([$residentId]);
    respond(['advance_decisions' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(AuditedRepository $repo, PDO $pdo, int $staffId, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $in         = input();
    $residentId = (int) ($in['resident_id'] ?? 0);
    $type       = (string) ($in['type'] ?? '');

    $errors = [];
    if ($residentId <= 0)                  $errors[] = 'resident_id is required';
    if (!in_array($type, AD_TYPES, true))  $errors[] = 'invalid type';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    $id = $repo->insert('advance_decisions', [
        'home_id'        => $homeId,
        'resident_id'    => $residentId,
        'type'           => $type,
        'in_place'       => isset($in['in_place']) ? ($in['in_place'] ? 1 : 0) : 1,
        'form_reference' => trim((string) ($in['form_reference'] ?? '')) ?: null,
        'completed_by'   => trim((string) ($in['completed_by'] ?? '')) ?: null,
        'date_completed' => $in['date_completed'] ?? null,
        'review_date'    => $in['review_date'] ?? null,
        'location'       => trim((string) ($in['location'] ?? '')) ?: null,
        'notes'          => trim((string) ($in['notes'] ?? '')) ?: null,
        'recorded_by'    => $staffId,
        'created_at'     => nowStr(),
    ], 'advance_decision');

    respond(['id' => $id], 201);
}

function handleUpdate(AuditedRepository $repo, PDO $pdo, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedAd($pdo, $id, $homeId);
    $in = input();

    if (isset($in['type']) && !in_array($in['type'], AD_TYPES, true)) {
        respond(['error' => 'invalid type'], 422);
    }

    $data    = [];
    $allowed = ['type', 'in_place', 'form_reference', 'completed_by',
                 'date_completed', 'review_date', 'location', 'notes'];
    foreach ($allowed as $col) {
        if (array_key_exists($col, $in)) {
            $data[$col] = ($col === 'in_place') ? ($in[$col] ? 1 : 0) : $in[$col];
        }
    }
    if (empty($data)) {
        respond(['error' => 'no fields to update'], 422);
    }

    $repo->update('advance_decisions', $id, $data, 'advance_decision');
    respond(['updated' => $id]);
}

function handleDelete(AuditedRepository $repo, PDO $pdo, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedAd($pdo, $id, $homeId);
    $repo->softDelete('advance_decisions', $id, 'advance_decision');
    respond(['deleted' => $id]);
}
