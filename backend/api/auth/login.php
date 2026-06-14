<?php
// POST /auth/login.php  { email, password }
require __DIR__ . '/../config.php';

$in = json_input();
$email = trim($in['email'] ?? '');
$password = $in['password'] ?? '';
if ($email === '' || $password === '') fail('Email and password required');

$stmt = db()->prepare(
    'SELECT s.*, h.name AS home_name
     FROM staff s
     LEFT JOIN homes h ON h.id = s.home_id
     WHERE s.email = ? AND s.active = 1'
);
$stmt->execute([$email]);
$user = $stmt->fetch();

if (!$user || !password_verify($password, $user['password_hash'])) {
    fail('Invalid credentials', 401);
}

$canSwitch = ((int)($user['can_switch_homes'] ?? 0) === 1) || $user['role'] === 'admin';

$token = jwt_encode([
    'sub'        => (int)$user['id'],
    'company'    => (int)($user['company_id'] ?? 0),
    'home'       => (int)$user['home_id'],
    'role'       => $user['role'],
    'can_switch' => $canSwitch,
]);

audit((int)$user['id'], 'login', 'staff', (int)$user['id']);

respond([
    'token' => $token,
    'user' => [
        'id' => (int)$user['id'],
        'name' => $user['name'],
        'email' => $user['email'],
        'role' => $user['role'],
        'company_id' => (int)($user['company_id'] ?? 0),
        'home_id' => (int)$user['home_id'],
        'home_name' => $user['home_name'],
        'can_switch_homes' => $canSwitch ? 1 : 0,
        'on_shift' => (int)$user['on_shift'],
    ],
]);
