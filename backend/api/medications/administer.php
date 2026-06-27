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

// Flutter sends ISO-8601 with T separator and optional Z/fractional seconds
// (e.g. "2026-06-27T08:00:00.000Z"). MySQL DATETIME rejects the Z suffix and
// stores 0000-00-00, breaking the mar_due slot-match lookup. Strip to plain
// "Y-m-d H:i:s", preserving the clock time without timezone conversion so it
// stays consistent with the HH:MM values stored in medications.times.
function normaliseDatetime(?string $val, string $fallback): string {
    if ($val === null || $val === '') return $fallback;
    $clean = preg_replace('/\.\d*Z?$/', '', str_replace('T', ' ', trim($val)));
    // Validate result is a parseable datetime
    return (strtotime($clean) !== false) ? $clean : $fallback;
}

$now            = date('Y-m-d H:i:s');
$administeredAt = normaliseDatetime($in['administered_at'] ?? null, $now);
$scheduledFor   = normaliseDatetime($in['scheduled_for']   ?? null, $administeredAt);

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
