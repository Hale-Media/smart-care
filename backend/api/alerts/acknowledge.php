<?php
// POST /alerts/acknowledge.php
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();
$id = (int)($in['id'] ?? 0);
$staffId = (int)($in['staff_id'] ?? $auth['sub']);
if ($id === 0) fail('id is required');

$stmt = db()->prepare(
    "UPDATE alerts
     SET status = 'acknowledged', acknowledged_at = NOW(), acknowledged_by = ?
     WHERE id = ? AND home_id = ? AND status IN ('active','escalated')"
);
$stmt->execute([$staffId, $id, (int)$auth['home']]);
if ($stmt->rowCount() === 0) fail('Alert not found or already actioned', 404);
audit((int)$auth['sub'], 'acknowledge', 'alert', $id);
respond(['ok' => true]);
