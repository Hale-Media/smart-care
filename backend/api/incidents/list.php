<?php
// GET /incidents/list.php?status=open&resident_id=5
require __DIR__ . '/../config.php';
$auth = require_auth();
$homeId = (int)$auth['home'];

$status     = $_GET['status']      ?? null;
$residentId = isset($_GET['resident_id']) ? (int)$_GET['resident_id'] : null;

$where = ['r.home_id = ?'];
$params = [$homeId];

if ($status !== null) {
    $where[] = 'i.status = ?';
    $params[] = $status;
}
if ($residentId !== null) {
    $where[] = 'i.resident_id = ?';
    $params[] = $residentId;
}

$sql = "SELECT i.*, CONCAT(r.first_name,' ',r.last_name) AS resident_name,
               s.name AS reported_by_name
        FROM incidents i
        JOIN residents r ON r.id = i.resident_id
        LEFT JOIN staff s ON s.id = i.reported_by
        WHERE " . implode(' AND ', $where) . "
        ORDER BY i.occurred_at DESC
        LIMIT 200";

$stmt = db()->prepare($sql);
$stmt->execute($params);
respond(['incidents' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
