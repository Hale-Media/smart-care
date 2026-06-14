<?php
// POST /staff/create.php   (manager/admin only)
// Body: { name, email, password, role, pin?, home_id? }
require __DIR__ . '/../config.php';
$auth = require_auth();

if (!in_array($auth['role'] ?? '', ['manager', 'admin'], true)) {
    fail('Insufficient permissions', 403);
}

$in = json_input();
$name  = trim($in['name'] ?? '');
$email = trim($in['email'] ?? '');
$pass  = $in['password'] ?? '';
$role  = $in['role'] ?? 'carer';
$pin   = $in['pin'] ?? null;
$monitoringCompetency = trim((string)($in['monitoring_competency'] ?? ''));
$supervisionNotes = trim((string)($in['supervision_notes'] ?? ''));
$competencyReviewDate = $in['competency_review_date'] ?? null;
$companyId = (int)($auth['company'] ?? 0);
$homeId = (int)($in['home_id'] ?? $auth['home'] ?? 0);

if ($name === '' || $email === '' || $pass === '') fail('name, email and password are required');
if (!in_array($role, ['carer','seniorCarer','nurse','manager','admin'], true)) fail('Invalid role');
if (strlen($pass) < 8) fail('Password must be at least 8 characters');
if ($pin !== null && !preg_match('/^\d{4,6}$/', (string)$pin)) fail('PIN must be 4–6 digits');

// New staff may only be placed in a home that belongs to the caller's company.
$own = db()->prepare('SELECT id FROM homes WHERE id = ? AND company_id = ?');
$own->execute([$homeId, $companyId]);
if (!$own->fetch()) fail('Home does not belong to your company', 403);

$check = db()->prepare('SELECT id FROM staff WHERE email = ?');
$check->execute([$email]);
if ($check->fetch()) fail('A user with that email already exists', 409);

$stmt = db()->prepare(
    'INSERT INTO staff (
        company_id, home_id, name, email, password_hash, role, pin_hash,
        monitoring_competency, supervision_notes, competency_review_date,
        on_shift, active
     ) VALUES (?,?,?,?,?,?,?,?,?,?,0,1)'
);
$stmt->execute([
    $companyId, $homeId, $name, $email,
    password_hash($pass, PASSWORD_BCRYPT), $role,
    $pin !== null ? password_hash((string)$pin, PASSWORD_BCRYPT) : null,
    $monitoringCompetency !== '' ? $monitoringCompetency : null,
    $supervisionNotes !== '' ? $supervisionNotes : null,
    $competencyReviewDate,
]);
$id = (int)db()->lastInsertId();
audit((int)$auth['sub'], 'create', 'staff', $id, "role=$role");

respond(['user' => [
    'id' => $id, 'name' => $name, 'email' => $email, 'role' => $role,
    'home_id' => $homeId, 'company_id' => $companyId,
    'monitoring_competency' => $monitoringCompetency !== '' ? $monitoringCompetency : null,
    'supervision_notes' => $supervisionNotes !== '' ? $supervisionNotes : null,
    'competency_review_date' => $competencyReviewDate,
]], 201);
