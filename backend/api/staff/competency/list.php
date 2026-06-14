<?php
// GET /staff/competency/list.php?staff_id=123
// Returns all competency records for a staff member in the caller's company.
require __DIR__ . '/../../config.php';
$auth = require_auth();
if (!in_array($auth['role'] ?? '', ['manager', 'admin', 'nurse', 'seniorCarer'], true)) {
    fail('Insufficient permissions', 403);
}

$staffId   = (int)($_GET['staff_id'] ?? 0);
$companyId = (int)($auth['company'] ?? 0);
if ($staffId === 0) fail('staff_id is required');

// Confirm the target staff member belongs to the caller's company.
$own = db()->prepare('SELECT id FROM staff WHERE id = ? AND company_id = ?');
$own->execute([$staffId, $companyId]);
if (!$own->fetch()) fail('Staff member not found', 404);

$stmt = db()->prepare(
    'SELECT * FROM staff_competency_records
     WHERE staff_id = ?
     ORDER BY assessed_date DESC'
);
$stmt->execute([$staffId]);
respond(['records' => $stmt->fetchAll()]);
