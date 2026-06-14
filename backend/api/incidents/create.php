<?php
// POST /incidents/create.php
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();

$residentId = (int)($in['resident_id'] ?? 0);
if ($residentId === 0) fail('resident_id is required');

// Verify resident belongs to this home.
$own = db()->prepare('SELECT id FROM residents WHERE id = ? AND home_id = ?');
$own->execute([$residentId, (int)$auth['home']]);
if (!$own->fetch()) fail('Resident not found', 404);

$staffId = (int)$auth['sub'];

$stmt = db()->prepare(
    "INSERT INTO incidents
        (resident_id, category, severity, occurred_at, reported_at, reported_by,
         location, description, immediate_action, injury, witnessed,
         family_notified, gp_notified, cqc_notifiable, safeguarding, status)
     VALUES (?, ?, ?, ?, NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'open')"
);
$stmt->execute([
    $residentId,
    $in['category']         ?? 'other',
    $in['severity']         ?? 'minor',
    $in['occurred_at']      ?? date('Y-m-d H:i:s'),
    $staffId,
    $in['location']         ?? null,
    $in['description']      ?? '',
    $in['immediate_action'] ?? null,
    !empty($in['injury'])          ? 1 : 0,
    !empty($in['witnessed'])       ? 1 : 0,
    !empty($in['family_notified']) ? 1 : 0,
    !empty($in['gp_notified'])     ? 1 : 0,
    !empty($in['cqc_notifiable'])  ? 1 : 0,
    !empty($in['safeguarding'])    ? 1 : 0,
]);
$newId = (int)db()->lastInsertId();
audit($staffId, 'create', 'incident', $newId, $in['category'] ?? null);

$row = db()->prepare(
    "SELECT i.*, CONCAT(r.first_name,' ',r.last_name) AS resident_name,
            s.name AS reported_by_name
     FROM incidents i
     JOIN residents r ON r.id = i.resident_id
     LEFT JOIN staff s ON s.id = i.reported_by
     WHERE i.id = ?"
);
$row->execute([$newId]);
respond(['incident' => $row->fetch()], 201);
