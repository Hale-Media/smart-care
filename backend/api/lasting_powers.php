<?php
declare(strict_types=1);

/**
 * /api/lasting_powers.php — Smart Care
 *
 * GET    ?resident_id=1  -> all lasting powers / LPAs for a resident
 * POST   {resident_id, type, attorney_name, ...}  -> create
 * PUT    ?id=5 {...}     -> update
 * DELETE ?id=5           -> soft delete
 */

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/lib/AuditedRepository.php';

header('Content-Type: application/json');

$jwt = require_auth();
$pdo = db();

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
    $staffId = (int) $jwt['sub'];
    $homeId  = (int) $jwt['home'];

    match ($_SERVER['REQUEST_METHOD']) {
        'GET'          => handleGet($pdo, $homeId),
        'POST'         => handleCreate($pdo, $staffId, $homeId),
        'PUT', 'PATCH' => handleUpdate($pdo, $staffId, $homeId),
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
        'SELECT * FROM lasting_powers
         WHERE resident_id = ? AND deleted_at IS NULL
         ORDER BY type, created_at DESC'
    );
    $stmt->execute([$residentId]);
    respond(['lasting_powers' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(PDO $pdo, int $staffId, int $homeId): never
{
    $in           = input();
    $residentId   = (int) ($in['resident_id'] ?? 0);
    $type         = (string) ($in['type'] ?? '');
    $attorneyName = trim((string) ($in['attorney_name'] ?? ''));

    $errors = [];
    if ($residentId <= 0)                         $errors[] = 'resident_id is required';
    if (!in_array($type, LP_TYPES, true))         $errors[] = 'invalid type';
    if ($attorneyName === '')                      $errors[] = 'attorney_name is required';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    $stmt = $pdo->prepare(
        'INSERT INTO lasting_powers
         (home_id, resident_id, type, attorney_name, attorney_contact,
          registered, reference, notes, recorded_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $homeId,
        $residentId,
        $type,
        $attorneyName,
        trim((string) ($in['attorney_contact'] ?? '')) ?: null,
        isset($in['registered']) && $in['registered'] ? 1 : 0,
        trim((string) ($in['reference'] ?? '')) ?: null,
        trim((string) ($in['notes'] ?? '')) ?: null,
        $staffId,
        nowStr(),
    ]);
    $id = (int) $pdo->lastInsertId();
    respond(['id' => $id], 201);
}

function handleUpdate(PDO $pdo, int $staffId, int $homeId): never
{
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedLp($pdo, $id, $homeId);
    $in = input();

    $fields = [];
    $params = [];

    $allowed = ['type', 'attorney_name', 'attorney_contact', 'registered', 'reference', 'notes'];
    foreach ($allowed as $col) {
        if (array_key_exists($col, $in)) {
            $fields[] = "$col = ?";
            $params[] = $col === 'registered' ? ($in[$col] ? 1 : 0) : $in[$col];
        }
    }
    if (isset($in['type']) && !in_array($in['type'], LP_TYPES, true)) {
        respond(['error' => 'invalid type'], 422);
    }
    if (empty($fields)) {
        respond(['error' => 'no fields to update'], 422);
    }
    $params[] = $id;
    $pdo->prepare('UPDATE lasting_powers SET ' . implode(', ', $fields) . ' WHERE id = ?')
        ->execute($params);
    respond(['updated' => $id]);
}

function handleDelete(PDO $pdo, int $staffId, int $homeId): never
{
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedLp($pdo, $id, $homeId);
    $pdo->prepare('UPDATE lasting_powers SET deleted_at = ?, deleted_by = ? WHERE id = ?')
        ->execute([nowStr(), $staffId, $id]);
    respond(['deleted' => $id]);
}
