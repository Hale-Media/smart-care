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

if (array_key_exists('photos', $in)) {
    $newPhotos = is_array($in['photos']) ? $in['photos'] : [];

    // Fetch current photos so we can delete files that were removed.
    $cur = db()->prepare('SELECT photos FROM incidents WHERE id = ?');
    $cur->execute([$id]);
    $existing = json_decode($cur->fetchColumn() ?? '[]', true) ?? [];

    $uploadDir = rtrim($_SERVER['DOCUMENT_ROOT'], '/') . '/uploads/incident_photos/';
    foreach (array_diff($existing, $newPhotos) as $url) {
        $filename = basename(parse_url($url, PHP_URL_PATH));
        // Only delete files that match our naming pattern (security guard).
        if (preg_match('/^[a-f0-9]{32}\.(jpg|png|gif|webp)$/', $filename)) {
            @unlink($uploadDir . $filename);
        }
    }

    $sets[] = 'photos = ?';
    $vals[] = json_encode($newPhotos);
}
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
$result = $row->fetch();
$result['photos'] = json_decode($result['photos'] ?? '[]', true) ?? [];
respond(['incident' => $result]);
