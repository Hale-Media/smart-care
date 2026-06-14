<?php
// GET /vitals/history.php?resident_id=123&limit=50
require __DIR__ . '/../config.php';
require_auth();
$residentId = (int)($_GET['resident_id'] ?? 0);
$limit = min(200, max(1, (int)($_GET['limit'] ?? 50)));
if ($residentId === 0) fail('resident_id is required');

$stmt = db()->prepare(
    'SELECT * FROM vitals WHERE resident_id = ? ORDER BY recorded_at DESC LIMIT ?'
);
$stmt->bindValue(1, $residentId, PDO::PARAM_INT);
$stmt->bindValue(2, $limit, PDO::PARAM_INT);
$stmt->execute();
respond(['vitals' => $stmt->fetchAll()]);
