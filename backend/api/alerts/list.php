<?php
// GET /alerts/list.php?open=1
require __DIR__ . '/../config.php';
$auth = require_auth();
$homeId = (int)$auth['home'];
$openOnly = ($_GET['open'] ?? '0') === '1';

$sql = "SELECT a.*, CONCAT(r.first_name,' ',r.last_name) AS resident_name, r.room_number AS resident_room
        FROM alerts a
        LEFT JOIN residents r ON r.id = a.resident_id
        WHERE a.home_id = ?";
if ($openOnly) $sql .= " AND a.status IN ('active','escalated')";
$sql .= " ORDER BY a.created_at DESC LIMIT 200";

$stmt = db()->prepare($sql);
$stmt->execute([$homeId]);
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($rows as &$row) {
    if (empty($row['location']) && !empty($row['resident_room'])) {
        $row['location'] = $row['resident_room'];
    }
    unset($row['resident_room']);
}
respond(['alerts' => $rows]);
