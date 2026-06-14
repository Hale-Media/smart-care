<?php
// POST /care_calls/generate.php { resident_id }
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();
$residentId = (int)($in['resident_id'] ?? 0);
if ($residentId === 0) fail('resident_id is required');

$stmt = db()->prepare(
    'SELECT id, first_name, last_name, care_level, call_times
     FROM residents
     WHERE id = ? AND home_id = ? AND active = 1'
);
$stmt->execute([$residentId, (int)$auth['home']]);
$resident = $stmt->fetch();
if (!$resident) fail('Resident not found', 404);
if (($resident['care_level'] ?? '') !== 'home_care') {
    fail('Resident is not configured for home care', 400);
}

$times = array_values(array_filter(array_map('trim', explode(',', (string)($resident['call_times'] ?? '')))));
$today = (new DateTimeImmutable('today'))->format('Y-m-d');

if ($times) {
    $insert = db()->prepare(
        'INSERT INTO care_calls (resident_id, scheduled_date, scheduled_time)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE scheduled_time = VALUES(scheduled_time)'
    );
    foreach ($times as $time) {
        $insert->execute([$residentId, $today, $time]);
    }
}

$list = db()->prepare(
    'SELECT cc.*, CONCAT(r.first_name, " ", r.last_name) AS resident_name,
            s.name AS confirmed_by_name
     FROM care_calls cc
     JOIN residents r ON r.id = cc.resident_id
     LEFT JOIN staff s ON s.id = cc.confirmed_by
     WHERE cc.resident_id = ? AND cc.scheduled_date = ?
     ORDER BY cc.scheduled_time'
);
$list->execute([$residentId, $today]);
respond(['calls' => $list->fetchAll()]);