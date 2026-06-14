<?php
// POST /residents/discharge.php  { id }  — soft-deactivate (never hard delete).
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();
$id = (int)($in['id'] ?? 0);
if ($id === 0) fail('id is required');

$stmt = db()->prepare('UPDATE residents SET active = 0 WHERE id = ? AND home_id = ?');
$stmt->execute([$id, (int)$auth['home']]);
audit((int)$auth['sub'], 'discharge', 'resident', $id);
respond(['ok' => true]);
