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

$staffId      = (int)$auth['sub'];
$administeredAt = $in['administered_at'] ?? date('Y-m-d H:i:s');
$scheduledFor   = $in['scheduled_for']   ?? $administeredAt;

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
