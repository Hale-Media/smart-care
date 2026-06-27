<?php
// POST /medications/delete.php  (nurse/manager/admin only)
// Soft-deletes by setting active = 0. Medications are never hard-deleted
// so the MAR history and audit trail remain intact.
// Body: { id }
require __DIR__ . '/../config.php';
$auth = require_auth();

if (!in_array($auth['role'] ?? '', ['nurse', 'manager', 'admin'], true)) {
    fail('Insufficient permissions', 403);
}

$in = json_input();
$id = (int)($in['id'] ?? 0);
if ($id === 0) fail('id is required');

// Verify the medication belongs to a resident in the caller's home.
$own = db()->prepare(
    'SELECT m.id FROM medications m
     JOIN residents r ON r.id = m.resident_id
     WHERE m.id = ? AND r.home_id = ?'
);
$own->execute([$id, (int)$auth['home']]);
if (!$own->fetch()) fail('Medication not found', 404);

db()->prepare('UPDATE medications SET active = 0 WHERE id = ?')->execute([$id]);

audit((int)$auth['sub'], 'deactivate', 'medication', $id, null, (int)$auth['home']);

respond(['ok' => true]);
