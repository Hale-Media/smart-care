<?php
// GET /residents/get.php?id=123
require __DIR__ . '/../config.php';
$auth = require_auth();
$id = (int)($_GET['id'] ?? 0);

$stmt = db()->prepare('SELECT * FROM residents WHERE id = ? AND home_id = ?');
$stmt->execute([$id, (int)$auth['home']]);
$r = $stmt->fetch();
if (!$r) fail('Resident not found', 404);

$r['conditions']  = $r['conditions']  ? array_map('trim', explode(',', $r['conditions']))  : [];
$r['allergies']   = $r['allergies']   ? array_map('trim', explode(',', $r['allergies']))   : [];
$r['medications'] = $r['medications'] ? array_map('trim', explode(',', $r['medications'])) : [];
$r['call_times'] = $r['call_times'] ? array_map('trim', explode(',', $r['call_times'])) : [];
$r['monitoring_methods'] = $r['monitoring_methods']
	? array_map('trim', explode(',', $r['monitoring_methods']))
	: [];
respond(['resident' => $r]);
