<?php
// GET /care_calls/history.php?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD[&resident_id=N][&status=confirmed|pending]
require __DIR__ . '/../config.php';
$auth = require_auth();

$startDate = trim($_GET['start_date'] ?? '');
$endDate   = trim($_GET['end_date']   ?? '');
if ($startDate === '' || $endDate === '') fail('start_date and end_date are required');
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $endDate)) {
    fail('Dates must be YYYY-MM-DD');
}
if ($startDate > $endDate) fail('start_date must not be after end_date');

$residentId = isset($_GET['resident_id']) ? (int)$_GET['resident_id'] : null;
$status     = $_GET['status'] ?? null;

$where  = 'cc.scheduled_date BETWEEN ? AND ? AND r.home_id = ?';
$params = [$startDate, $endDate, (int)$auth['home']];

if ($residentId !== null && $residentId > 0) {
    $where   .= ' AND cc.resident_id = ?';
    $params[] = $residentId;
}
if ($status === 'confirmed') {
    $where .= ' AND cc.confirmed = 1';
} elseif ($status === 'pending') {
    $where .= ' AND cc.confirmed = 0';
}

$stmt = db()->prepare(
    "SELECT cc.*,
            CONCAT(r.first_name, ' ', r.last_name) AS resident_name,
            s.name AS confirmed_by_name
     FROM care_calls cc
     JOIN residents r ON r.id = cc.resident_id
     LEFT JOIN staff s ON s.id = cc.confirmed_by
     WHERE $where
     ORDER BY cc.scheduled_date DESC, cc.scheduled_time ASC"
);
$stmt->execute($params);
respond(['calls' => $stmt->fetchAll()]);
