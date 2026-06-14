<?php
// POST /staff/competency/create.php
// Body: { staff_id, competency, assessed_date, assessed_by, expiry_date?, outcome?, notes? }
require __DIR__ . '/../../config.php';
$auth = require_auth();
if (!in_array($auth['role'] ?? '', ['manager', 'admin', 'nurse', 'seniorCarer'], true)) {
    fail('Insufficient permissions', 403);
}

$in        = json_input();
$staffId   = (int)($in['staff_id'] ?? 0);
$companyId = (int)($auth['company'] ?? 0);

if ($staffId === 0) fail('staff_id is required');

$competency   = trim($in['competency'] ?? '');
$assessedDate = trim($in['assessed_date'] ?? '');
$assessedBy   = trim($in['assessed_by'] ?? '');
if ($competency === '') fail('competency is required');
if ($assessedDate === '') fail('assessed_date is required');
if ($assessedBy === '') fail('assessed_by is required');

$allowedOutcomes = ['passed', 'failed', 'pending'];
$outcome = $in['outcome'] ?? 'passed';
if (!in_array($outcome, $allowedOutcomes, true)) fail('Invalid outcome');

// Confirm the target staff member belongs to the caller's company.
$own = db()->prepare('SELECT id FROM staff WHERE id = ? AND company_id = ?');
$own->execute([$staffId, $companyId]);
if (!$own->fetch()) fail('Staff member not found', 404);

$stmt = db()->prepare(
    'INSERT INTO staff_competency_records
       (staff_id, competency, assessed_date, expiry_date, assessed_by, outcome, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?)'
);
$stmt->execute([
    $staffId,
    $competency,
    $assessedDate,
    $in['expiry_date'] ?? null,
    $assessedBy,
    $outcome,
    $in['notes'] ?? null,
]);
$id = (int)db()->lastInsertId();
audit((int)$auth['sub'], 'create', 'competency_record', $id, "$competency / $outcome");

$row = db()->prepare('SELECT * FROM staff_competency_records WHERE id = ?');
$row->execute([$id]);
respond(['record' => $row->fetch()], 201);
