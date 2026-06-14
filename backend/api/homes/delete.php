<?php
// POST /homes/delete.php  (admin only)
// Body: { id }
require __DIR__ . '/../config.php';
$auth = require_auth();

if (($auth['role'] ?? '') !== 'admin') {
    fail('Only administrators can delete homes', 403);
}

$in = json_input();
$id = (int)($in['id'] ?? 0);
$companyId = (int)($auth['company'] ?? 0);

if ($id === 0) fail('id is required');

$own = db()->prepare('SELECT id FROM homes WHERE id = ? AND company_id = ?');
$own->execute([$id, $companyId]);
if (!$own->fetch()) fail('Home not found', 404);

$residents = db()->prepare('SELECT COUNT(*) FROM residents WHERE home_id = ?');
$residents->execute([$id]);
if ((int)$residents->fetchColumn() > 0) {
    fail('Cannot delete a home that still has residents. Discharge them first.', 409);
}

$staff = db()->prepare('SELECT COUNT(*) FROM staff WHERE home_id = ? AND active = 1');
$staff->execute([$id]);
if ((int)$staff->fetchColumn() > 0) {
    fail('Cannot delete a home with active staff. Deactivate or reassign them first.', 409);
}

db()->prepare('DELETE FROM homes WHERE id = ?')->execute([$id]);
audit((int)$auth['sub'], 'delete', 'home', $id, null);

respond(['ok' => true]);
