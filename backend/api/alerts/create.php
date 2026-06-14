<?php
// POST /alerts/create.php  — sensor gateway / device ingestion endpoint.
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();

$stmt = db()->prepare(
    'INSERT INTO alerts (home_id, resident_id, type, severity, status, location, lat, lng, message, source)
     VALUES (?,?,?,?,?,?,?,?,?,?)'
);
$stmt->execute([
    (int)$auth['home'],
    $in['resident_id'] ?? null,
    $in['type'] ?? 'manual',
    $in['severity'] ?? 'high',
    'active',
    $in['location'] ?? null,
    $in['lat'] ?? null,
    $in['lng'] ?? null,
    $in['message'] ?? null,
    $in['source'] ?? 'app',
]);
$id = (int)db()->lastInsertId();
audit((int)$auth['sub'], 'create', 'alert', $id);
respond(['alert' => ['id' => $id] + $in], 201);
