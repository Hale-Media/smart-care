<?php
// POST /staff/delete.php  (manager/admin only)
// Body: { id }
require __DIR__ . '/../config.php';
$auth = require_auth();
if (!in_array($auth['role'] ?? '', ['admin', 'manager'], true)) {
    fail('Insufficient permissions', 403);
}

$in = json_input();
$id = (int)($in['id'] ?? 0);
$callerId = (int)$auth['sub'];
$companyId = (int)($auth['company'] ?? 0);
if ($id === 0) fail('id is required');
if ($id === $callerId) fail('You cannot delete your own account', 400);

// Target must be in the caller's company.
$own = db()->prepare('SELECT id, role FROM staff WHERE id = ? AND company_id = ?');
$own->execute([$id, $companyId]);
$target = $own->fetch();
if (!$target) fail('Staff member not found in your company', 404);
if ($target['role'] === 'admin') fail('Admin accounts cannot be deleted', 403);

// Prevent deleting if they are the sole remaining active staff member.
$count = db()->prepare('SELECT COUNT(*) FROM staff WHERE company_id = ? AND active = 1');
$count->execute([$companyId]);
if ((int)$count->fetchColumn() <= 1) fail('Cannot delete the last active staff member', 400);

try {
    $stmt = db()->prepare('DELETE FROM staff WHERE id = ?');
    $stmt->execute([$id]);
} catch (PDOException $e) {
    // FK constraint — staff has linked records (vitals, rounds, etc.)
    fail('Cannot delete: staff has existing records. Deactivate instead.', 409);
}

audit($callerId, 'delete', 'staff', $id);
respond(['ok' => true]);
