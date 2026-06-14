<?php
// GET /residents/list.php?active=1&home_id=N
require __DIR__ . '/../config.php';
$auth = require_auth();

// Managers/admins may request residents for any home in their company.
$canViewAny = in_array($auth['role'] ?? '', ['manager', 'admin'], true);
if ($canViewAny && !empty($_GET['home_id'])) {
    $reqHome = (int)$_GET['home_id'];
    $own = db()->prepare('SELECT id FROM homes WHERE id = ? AND company_id = ?');
    $own->execute([$reqHome, (int)($auth['company'] ?? 0)]);
    $homeId = $own->fetch() ? $reqHome : (int)$auth['home'];
} else {
    $homeId = (int)$auth['home'];
}

$activeOnly = ($_GET['active'] ?? '1') === '1';

$sql = 'SELECT * FROM residents WHERE home_id = ?';
if ($activeOnly) $sql .= ' AND active = 1';
$sql .= ' ORDER BY last_name, first_name';

$stmt = db()->prepare($sql);
$stmt->execute([$homeId]);
$rows = $stmt->fetchAll();

// Normalise comma-separated lists into arrays for the client.
foreach ($rows as &$r) {
    $r['conditions']  = $r['conditions']  ? array_map('trim', explode(',', $r['conditions']))  : [];
    $r['allergies']   = $r['allergies']   ? array_map('trim', explode(',', $r['allergies']))   : [];
    $r['medications'] = $r['medications'] ? array_map('trim', explode(',', $r['medications'])) : [];
    $r['call_times'] = $r['call_times'] ? array_map('trim', explode(',', $r['call_times'])) : [];
    $r['monitoring_methods'] = $r['monitoring_methods']
        ? array_map('trim', explode(',', $r['monitoring_methods']))
        : [];
}
respond(['residents' => $rows]);
