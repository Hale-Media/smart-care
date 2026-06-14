<?php
// POST /alerts/resolve.php
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();
$id = (int)($in['id'] ?? 0);
if ($id === 0) fail('id is required');
$notes = !empty($in['notes']) ? trim($in['notes']) : null;

$stmt = db()->prepare(
    "UPDATE alerts
     SET status = 'resolved', resolved_at = NOW(), resolution_notes = ?
     WHERE id = ? AND home_id = ? AND status IN ('active','acknowledged','escalated')"
);
$stmt->execute([$notes, $id, (int)$auth['home']]);
if ($stmt->rowCount() === 0) fail('Alert not found or already resolved', 404);
audit((int)$auth['sub'], 'resolve', 'alert', $id, $notes);
respond(['ok' => true]);
