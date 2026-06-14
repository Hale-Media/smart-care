<?php
// GET /care_calls/list.php?resident_id=123&date=YYYY-MM-DD
require __DIR__ . '/../config.php';
$auth = require_auth();
$residentId = (int)($_GET['resident_id'] ?? 0);
if ($residentId === 0) fail('resident_id is required');
$date = trim($_GET['date'] ?? date('Y-m-d'));

$stmt = db()->prepare(
    'SELECT cc.*, CONCAT(r.first_name, " ", r.last_name) AS resident_name,
            s.name AS confirmed_by_name
     FROM care_calls cc
     JOIN residents r ON r.id = cc.resident_id
     LEFT JOIN staff s ON s.id = cc.confirmed_by
     WHERE cc.resident_id = ? AND r.home_id = ? AND cc.scheduled_date = ?
     ORDER BY cc.scheduled_time'
);
$stmt->execute([$residentId, (int)$auth['home'], $date]);
respond(['calls' => $stmt->fetchAll()]);