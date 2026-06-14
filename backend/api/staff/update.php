<?php
// POST /staff/update.php   (manager/admin only)
// Body: { id, can_switch_homes?, role?, active? }
// Updates a staff member who belongs to the caller's company.
require __DIR__ . '/../config.php';
$auth = require_auth();
if (!in_array($auth['role'] ?? '', ['admin', 'manager'], true)) {
    fail('Insufficient permissions', 403);
}

$in = json_input();
$id = (int)($in['id'] ?? 0);
$companyId = (int)($auth['company'] ?? 0);
if ($id === 0) fail('id is required');

// Target must be in the caller's company.
$own = db()->prepare('SELECT id FROM staff WHERE id = ? AND company_id = ?');
$own->execute([$id, $companyId]);
if (!$own->fetch()) fail('Staff member not found in your company', 404);

$sets = [];
$vals = [];
if (array_key_exists('can_switch_homes', $in)) {
    $sets[] = 'can_switch_homes = ?';
    $vals[] = !empty($in['can_switch_homes']) ? 1 : 0;
}
if (array_key_exists('role', $in)) {
    if (!in_array($in['role'], ['carer','seniorCarer','nurse','manager','admin'], true)) {
        fail('Invalid role');
    }
    $sets[] = 'role = ?';
    $vals[] = $in['role'];
}
if (array_key_exists('active', $in)) {
    $sets[] = 'active = ?';
    $vals[] = !empty($in['active']) ? 1 : 0;
}
if (empty($sets)) fail('Nothing to update');

$vals[] = $id;
$stmt = db()->prepare('UPDATE staff SET ' . implode(', ', $sets) . ' WHERE id = ?');
$stmt->execute($vals);
audit((int)$auth['sub'], 'update', 'staff', $id, implode(',', $sets));

respond(['ok' => true]);
