<?php
// DELETE /staff/competency/delete.php  { id }
require __DIR__ . '/../../config.php';
$auth = require_auth();
if (!in_array($auth['role'] ?? '', ['manager', 'admin'], true)) {
    fail('Insufficient permissions', 403);
}

$in        = json_input();
$id        = (int)($in['id'] ?? 0);
$companyId = (int)($auth['company'] ?? 0);
if ($id === 0) fail('id is required');

// Confirm record belongs to a staff member in the caller's company.
$own = db()->prepare(
    'SELECT cr.id FROM staff_competency_records cr
     JOIN staff s ON s.id = cr.staff_id
     WHERE cr.id = ? AND s.company_id = ?'
);
$own->execute([$id, $companyId]);
if (!$own->fetch()) fail('Record not found', 404);

db()->prepare('DELETE FROM staff_competency_records WHERE id = ?')->execute([$id]);
audit((int)$auth['sub'], 'delete', 'competency_record', $id);
respond(['ok' => true]);
