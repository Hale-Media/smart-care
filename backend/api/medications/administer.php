<?php
// POST /medications/administer.php
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();

$medicationId = (int)($in['medication_id'] ?? 0);
$residentId   = (int)($in['resident_id']   ?? 0);
if ($medicationId === 0) fail('medication_id is required');
if ($residentId === 0)   fail('resident_id is required');

// Verify medication belongs to a resident in the caller's home.
$own = db()->prepare(
    'SELECT m.id FROM medications m
     JOIN residents r ON r.id = m.resident_id
     WHERE m.id = ? AND r.home_id = ?'
);
$own->execute([$medicationId, (int)$auth['home']]);
if (!$own->fetch()) fail('Medication not found', 404);

$staffId = (int)$auth['sub'];

// Parse ISO 8601 strings from the Flutter client into MySQL-safe DATETIME strings.
// Flutter sends administered_at as local time and scheduled_for as UTC (with Z suffix);
// PHP's DateTime parser handles both correctly.
function parseDt(?string $raw): ?string {
    if (empty($raw)) return null;
    try { return (new DateTime($raw))->format('Y-m-d H:i:s'); }
    catch (Exception $e) { return null; }
}

$administeredAt = parseDt($in['administered_at'] ?? null) ?? date('Y-m-d H:i:s');
$scheduledFor   = parseDt($in['scheduled_for']   ?? null) ?? $administeredAt;

// Prevent duplicate entries for the same slot (e.g. double-tap).
$dup = db()->prepare(
    'SELECT id FROM mar_entries WHERE medication_id = ? AND scheduled_for = ? LIMIT 1'
);
$dup->execute([$medicationId, $scheduledFor]);
if ($dup->fetch()) fail('A MAR entry already exists for this slot', 409);

$stmt = db()->prepare(
    "INSERT INTO mar_entries
        (medication_id, resident_id, scheduled_for, administered_at,
         administered_by, outcome, witness, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
);
$stmt->execute([
    $medicationId,
    $residentId,
    $scheduledFor,
    $administeredAt,
    $staffId,
    $in['outcome'] ?? 'given',
    $in['witness'] ?? null,
    $in['notes']   ?? null,
]);
$newId = (int)db()->lastInsertId();
audit($staffId, 'administer', 'medication', $medicationId, $in['outcome'] ?? 'given');

$row = db()->prepare(
    "SELECT e.*, s.name AS administered_by_name
     FROM mar_entries e
     LEFT JOIN staff s ON s.id = e.administered_by
     WHERE e.id = ?"
);
$row->execute([$newId]);
respond(['entry' => $row->fetch()], 201);
