<?php
// POST /medications/update.php  (nurse/manager/admin only)
// Body: { id, name?, dose?, route?, frequency?, times?, prn?, prn_reason?,
//          controlled_drug?, instructions?, active? }
require __DIR__ . '/../config.php';
$auth = require_auth();

if (!in_array($auth['role'] ?? '', ['nurse', 'manager', 'admin'], true)) {
    fail('Insufficient permissions', 403);
}

$in = json_input();
$id = (int)($in['id'] ?? 0);
if ($id === 0) fail('id is required');

// Verify medication belongs to a resident in the caller's home.
$own = db()->prepare(
    'SELECT m.id FROM medications m
     JOIN residents r ON r.id = m.resident_id
     WHERE m.id = ? AND r.home_id = ?'
);
$own->execute([$id, (int)$auth['home']]);
if (!$own->fetch()) fail('Medication not found', 404);

$sets = [];
$vals = [];

foreach (['name', 'dose', 'route', 'frequency', 'prn_reason', 'instructions'] as $col) {
    if (array_key_exists($col, $in)) {
        $sets[] = "$col = ?";
        $vals[] = $in[$col];
    }
}
foreach (['prn', 'controlled_drug', 'active'] as $col) {
    if (array_key_exists($col, $in)) {
        $sets[] = "$col = ?";
        $vals[] = !empty($in[$col]) ? 1 : 0;
    }
}
if (array_key_exists('times', $in)) {
    $times = $in['times'];
    $sets[] = 'times = ?';
    $vals[] = is_array($times) ? implode(',', $times) : $times;
}

if (empty($sets)) fail('Nothing to update');
$vals[] = $id;

db()->prepare('UPDATE medications SET ' . implode(', ', $sets) . ' WHERE id = ?')
   ->execute($vals);
audit((int)$auth['sub'], 'update', 'medication', $id, null);

respond(['ok' => true]);
