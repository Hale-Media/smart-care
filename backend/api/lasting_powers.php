<?php
declare(strict_types=1);

/**
 * /api/lasting_powers.php — Smart Care
 *
 * GET    ?resident_id=1  -> all lasting powers / LPAs for a resident
 * POST   {resident_id, type, attorney_name, ...}  -> create  (senior+ only)
 * PUT    ?id=5 {...}     -> update                            (senior+ only)
 * DELETE ?id=5           -> soft delete                       (senior+ only)
 */

require_once __DIR__ . '/config.php';

header('Content-Type: application/json');

$jwt     = require_auth();
$pdo     = db();
$staffId = (int) $jwt['staff_id'];
$homeId  = (int) $jwt['home_id'];
$repo    = new AuditedRepository($pdo, $staffId, $homeId, $_SERVER['REMOTE_ADDR'] ?? null);

const LP_TYPES = ['lpa_health', 'lpa_property', 'deputy', 'appointee'];

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

function requireOwnedLp(PDO $pdo, int $id, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT lp.* FROM lasting_powers lp
         JOIN residents r ON r.id = lp.resident_id
         WHERE lp.id = ? AND r.home_id = ? AND lp.deleted_at IS NULL'
    );
    $stmt->execute([$id, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'lasting power not found'], 404);
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
        'SELECT * FROM lasting_powers
         WHERE resident_id = ? AND deleted_at IS NULL
         ORDER BY type, created_at DESC'
    );
    $stmt->execute([$residentId]);
    respond(['lasting_powers' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(AuditedRepository $repo, PDO $pdo, int $staffId, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $in           = input();
    $residentId   = (int) ($in['resident_id'] ?? 0);
    $type         = (string) ($in['type'] ?? '');
    $attorneyName = trim((string) ($in['attorney_name'] ?? ''));

    $errors = [];
    if ($residentId <= 0)                 $errors[] = 'resident_id is required';
    if (!in_array($type, LP_TYPES, true)) $errors[] = 'invalid type';
    if ($attorneyName === '')             $errors[] = 'attorney_name is required';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    $id = $repo->insert('lasting_powers', [
        'home_id'          => $homeId,
        'resident_id'      => $residentId,
        'type'             => $type,
        'attorney_name'    => $attorneyName,
        'attorney_contact' => trim((string) ($in['attorney_contact'] ?? '')) ?: null,
        'registered'       => isset($in['registered']) && $in['registered'] ? 1 : 0,
        'reference'        => trim((string) ($in['reference'] ?? '')) ?: null,
        'notes'            => trim((string) ($in['notes'] ?? '')) ?: null,
        'recorded_by'      => $staffId,
        'created_at'       => nowStr(),
    ], 'lasting_power');

    respond(['id' => $id], 201);
}

function handleUpdate(AuditedRepository $repo, PDO $pdo, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedLp($pdo, $id, $homeId);
    $in = input();

    if (isset($in['type']) && !in_array($in['type'], LP_TYPES, true)) {
        respond(['error' => 'invalid type'], 422);
    }

    $data    = [];
    $allowed = ['type', 'attorney_name', 'attorney_contact', 'registered', 'reference', 'notes'];
    foreach ($allowed as $col) {
        if (array_key_exists($col, $in)) {
            $data[$col] = ($col === 'registered') ? ($in[$col] ? 1 : 0) : $in[$col];
        }
    }
    if (empty($data)) {
        respond(['error' => 'no fields to update'], 422);
    }

    $repo->update('lasting_powers', $id, $data, 'lasting_power');
    respond(['updated' => $id]);
}

function handleDelete(AuditedRepository $repo, PDO $pdo, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedLp($pdo, $id, $homeId);
    $repo->softDelete('lasting_powers', $id, 'lasting_power');
    respond(['deleted' => $id]);
}
