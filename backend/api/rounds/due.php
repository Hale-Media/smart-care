<?php
// GET /rounds/due.php?from=2026-06-10T00:00:00&to=2026-06-10T23:59:59
require __DIR__ . '/../config.php';
$auth = require_auth();
$homeId = (int)$auth['home'];

$from = $_GET['from'] ?? date('Y-m-d 00:00:00');
$to   = $_GET['to']   ?? date('Y-m-d 23:59:59');

$stmt = db()->prepare(
    "SELECT cr.*, CONCAT(r.first_name,' ',r.last_name) AS resident_name,
            s.name AS completed_by_name
     FROM care_rounds cr
     JOIN residents r ON r.id = cr.resident_id
     LEFT JOIN staff s ON s.id = cr.completed_by
     WHERE r.home_id = ? AND cr.due_at BETWEEN ? AND ?
     ORDER BY cr.due_at"
);
$stmt->execute([$homeId, $from, $to]);
respond(['rounds' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
