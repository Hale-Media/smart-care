<?php
declare(strict_types=1);

/**
 * /api/advance_decisions.php — Smart Care
 *
 * GET    ?resident_id=1  -> all advance decisions for a resident
 * POST   {resident_id, type, ...}  -> create
 * PUT    ?id=5 {...}     -> update
 * DELETE ?id=5           -> soft delete
 */

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/lib/AuditedRepository.php';

header('Content-Type: application/json');

$jwt = require_auth();
$pdo = db();

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
        'SELECT * FROM advance_decisions
         WHERE resident_id = ? AND deleted_at IS NULL
         ORDER BY type, created_at DESC'
    );
    $stmt->execute([$residentId]);
    respond(['advance_decisions' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(PDO $pdo, int $staffId, int $homeId): never
{
    $in         = input();
    $residentId = (int) ($in['resident_id'] ?? 0);
    $type       = (string) ($in['type'] ?? '');

    $errors = [];
    if ($residentId <= 0)                    $errors[] = 'resident_id is required';
    if (!in_array($type, AD_TYPES, true))    $errors[] = 'invalid type';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    $stmt = $pdo->prepare(
        'INSERT INTO advance_decisions
         (home_id, resident_id, type, in_place, form_reference, completed_by,
          date_completed, review_date, location, notes, recorded_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $homeId,
        $residentId,
        $type,
        isset($in['in_place']) ? ($in['in_place'] ? 1 : 0) : 1,
        trim((string) ($in['form_reference'] ?? '')) ?: null,
        trim((string) ($in['completed_by'] ?? '')) ?: null,
        $in['date_completed'] ?? null,
        $in['review_date'] ?? null,
        trim((string) ($in['location'] ?? '')) ?: null,
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
    requireOwnedAd($pdo, $id, $homeId);
    $in = input();

    $fields = [];
    $params = [];

    $allowed = ['type', 'in_place', 'form_reference', 'completed_by',
                 'date_completed', 'review_date', 'location', 'notes'];
    foreach ($allowed as $col) {
        if (array_key_exists($col, $in)) {
            $fields[] = "$col = ?";
            $params[] = $col === 'in_place' ? ($in[$col] ? 1 : 0) : $in[$col];
        }
    }
    if (isset($in['type']) && !in_array($in['type'], AD_TYPES, true)) {
        respond(['error' => 'invalid type'], 422);
    }
    if (empty($fields)) {
        respond(['error' => 'no fields to update'], 422);
    }
    $params[] = $id;
    $pdo->prepare('UPDATE advance_decisions SET ' . implode(', ', $fields) . ' WHERE id = ?')
        ->execute($params);
    respond(['updated' => $id]);
}

function handleDelete(PDO $pdo, int $staffId, int $homeId): never
{
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedAd($pdo, $id, $homeId);
    $pdo->prepare('UPDATE advance_decisions SET deleted_at = ?, deleted_by = ? WHERE id = ?')
        ->execute([nowStr(), $staffId, $id]);
    respond(['deleted' => $id]);
}
