<?php
declare(strict_types=1);

/**
 * /api/dols.php — Smart Care
 *
 * GET    ?resident_id=1  -> all DoLS records for a resident
 * POST   {resident_id, status, ...}  -> create a record
 * PUT    ?id=5 {...}     -> update a record
 * DELETE ?id=5           -> soft delete
 */

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/lib/AuditedRepository.php';

header('Content-Type: application/json');

$jwt = require_auth();
$pdo = db();

const DOLS_STATUSES = ['not_required', 'urgent', 'applied', 'granted', 'declined', 'expired', 'ended'];

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

function requireOwnedDols(PDO $pdo, int $id, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT d.* FROM dols_authorisations d
         JOIN residents r ON r.id = d.resident_id
         WHERE d.id = ? AND r.home_id = ? AND d.deleted_at IS NULL'
    );
    $stmt->execute([$id, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'DoLS record not found'], 404);
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
        'SELECT * FROM dols_authorisations
         WHERE resident_id = ? AND deleted_at IS NULL
         ORDER BY created_at DESC'
    );
    $stmt->execute([$residentId]);
    respond(['dols' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(PDO $pdo, int $staffId, int $homeId): never
{
    $in         = input();
    $residentId = (int) ($in['resident_id'] ?? 0);
    $status     = (string) ($in['status'] ?? '');

    $errors = [];
    if ($residentId <= 0)                            $errors[] = 'resident_id is required';
    if (!in_array($status, DOLS_STATUSES, true))     $errors[] = 'invalid status';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    $stmt = $pdo->prepare(
        'INSERT INTO dols_authorisations
         (home_id, resident_id, status, urgent, reference, supervisory_body,
          applied_on, granted_on, expires_on, conditions, notes, recorded_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $homeId,
        $residentId,
        $status,
        isset($in['urgent']) && $in['urgent'] ? 1 : 0,
        trim((string) ($in['reference'] ?? '')) ?: null,
        trim((string) ($in['supervisory_body'] ?? '')) ?: null,
        $in['applied_on'] ?? null,
        $in['granted_on'] ?? null,
        $in['expires_on'] ?? null,
        trim((string) ($in['conditions'] ?? '')) ?: null,
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
    requireOwnedDols($pdo, $id, $homeId);
    $in = input();

    $fields = [];
    $params = [];

    $allowed = ['status', 'urgent', 'reference', 'supervisory_body',
                 'applied_on', 'granted_on', 'expires_on', 'conditions', 'notes'];
    foreach ($allowed as $col) {
        if (array_key_exists($col, $in)) {
            $fields[] = "$col = ?";
            $params[] = $col === 'urgent' ? ($in[$col] ? 1 : 0) : $in[$col];
        }
    }
    if (isset($in['status']) && !in_array($in['status'], DOLS_STATUSES, true)) {
        respond(['error' => 'invalid status'], 422);
    }
    if (empty($fields)) {
        respond(['error' => 'no fields to update'], 422);
    }
    $params[] = $id;
    $pdo->prepare('UPDATE dols_authorisations SET ' . implode(', ', $fields) . ' WHERE id = ?')
        ->execute($params);
    respond(['updated' => $id]);
}

function handleDelete(PDO $pdo, int $staffId, int $homeId): never
{
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedDols($pdo, $id, $homeId);
    $pdo->prepare('UPDATE dols_authorisations SET deleted_at = ?, deleted_by = ? WHERE id = ?')
        ->execute([nowStr(), $staffId, $id]);
    respond(['deleted' => $id]);
}
