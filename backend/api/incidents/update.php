<?php
// POST /incidents/update.php
// Body: { id, status?, description?, immediate_action?, family_notified?,
//          gp_notified?, cqc_notifiable?, safeguarding?, severity? }
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();

$id = (int)($in['id'] ?? 0);
if ($id === 0) fail('id is required');

// Verify incident belongs to this home via resident.
$own = db()->prepare(
    'SELECT i.id FROM incidents i
     JOIN residents r ON r.id = i.resident_id
     WHERE i.id = ? AND r.home_id = ?'
);
$own->execute([$id, (int)$auth['home']]);
if (!$own->fetch()) fail('Incident not found', 404);

$sets = [];
$vals = [];

foreach (['status', 'description', 'immediate_action', 'severity', 'location', 'injury_details', 'witnesses'] as $col) {
    if (array_key_exists($col, $in)) {
        $sets[] = "$col = ?";
        $vals[] = $in[$col];
    }
}
foreach (['family_notified', 'gp_notified', 'cqc_notifiable', 'safeguarding', 'injury', 'witnessed'] as $col) {
    if (array_key_exists($col, $in)) {
        $sets[] = "$col = ?";
        $vals[] = !empty($in[$col]) ? 1 : 0;
    }
}

if (empty($sets)) fail('Nothing to update');
$vals[] = $id;

db()->prepare('UPDATE incidents SET ' . implode(', ', $sets) . ' WHERE id = ?')
   ->execute($vals);

audit((int)$auth['sub'], 'update', 'incident', $id, $in['status'] ?? null);

$row = db()->prepare(
    "SELECT i.*, CONCAT(r.first_name,' ',r.last_name) AS resident_name,
            s.name AS reported_by_name
     FROM incidents i
     JOIN residents r ON r.id = i.resident_id
     LEFT JOIN staff s ON s.id = i.reported_by
     WHERE i.id = ?"
);
$row->execute([$id]);
respond(['incident' => $row->fetch()]);
