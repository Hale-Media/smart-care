<?php
// POST /medications/create.php  (nurse/manager/admin only)
require __DIR__ . '/../config.php';
$auth = require_auth();

if (!in_array($auth['role'] ?? '', ['nurse', 'manager', 'admin'], true)) {
    fail('Insufficient permissions', 403);
}

$in = json_input();
$residentId = (int)($in['resident_id'] ?? 0);
if ($residentId === 0) fail('resident_id is required');

// Verify resident belongs to this home.
$own = db()->prepare('SELECT id FROM residents WHERE id = ? AND home_id = ?');
$own->execute([$residentId, (int)$auth['home']]);
if (!$own->fetch()) fail('Resident not found', 404);

$times = $in['times'] ?? [];
$timesStr = is_array($times) ? implode(',', $times) : (string)$times;

$stmt = db()->prepare(
    "INSERT INTO medications
        (resident_id, name, dose, route, frequency, times, prn, prn_reason,
         controlled_drug, instructions, start_date)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
);
$stmt->execute([
    $residentId,
    $in['name'] ?? '',
    $in['dose'] ?? '',
    $in['route'] ?? 'oral',
    $in['frequency'] ?? '',
    $timesStr,
    !empty($in['prn']) ? 1 : 0,
    $in['prn_reason'] ?? null,
    !empty($in['controlled_drug']) ? 1 : 0,
    $in['instructions'] ?? null,
    $in['start_date'] ?? null,
]);
$newId = (int)db()->lastInsertId();
audit((int)$auth['sub'], 'create', 'medication', $newId, $in['name'] ?? null);

$row = db()->prepare('SELECT * FROM medications WHERE id = ?');
$row->execute([$newId]);
respond(['medication' => $row->fetch()], 201);
