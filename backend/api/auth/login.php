<?php
// POST /auth/login.php  { email, password }
require __DIR__ . '/../config.php';

$in = json_input();
$email = strtolower(trim($in['email'] ?? ''));
$password = $in['password'] ?? '';
if ($email === '' || $password === '') fail('Email and password required');

// ── Brute-force protection, keyed on the account (not IP — care homes
// share one public IP, so an IP lock would freeze the whole shift). ──
$rl  = new RateLimiter(db(), 'login', 5, 900, 900);   // 5 / 15 min, 15 min lock
$key = 'login:' . $email;
if (($wait = $rl->lockedFor($key)) !== null) {
    fail('Too many attempts. Try again in ' . (int) ceil($wait / 60) . ' minute(s).', 429);
}

$stmt = db()->prepare(
    'SELECT s.*, h.name AS home_name
     FROM staff s
     LEFT JOIN homes h ON h.id = s.home_id
     WHERE s.email = ? AND s.active = 1'
);
$stmt->execute([$email]);
$user = $stmt->fetch();

// Equalise timing whether or not the account exists (valid bcrypt dummy, so
// the verify does real work and can't be distinguished by response time).
$hash = $user['password_hash'] ?? '$2y$10$AC0UnYpopD7karWAfTQ4Bupg0DyjDW8LS20ecv0mtWqk0BZoHPQdK';
if (!password_verify($password, $hash) || !$user) {
    $rl->recordFailure($key);
    fail('Invalid credentials', 401);
}
$rl->recordSuccess($key);

$canSwitch = ((int)($user['can_switch_homes'] ?? 0) === 1) || $user['role'] === 'admin';

$token = jwt_encode([
    'sub'        => (int)$user['id'],
    'company'    => (int)($user['company_id'] ?? 0),
    'home'       => (int)$user['home_id'],
    'role'       => $user['role'],
    'can_switch' => $canSwitch,
    'tv'         => (int)($user['token_version'] ?? 1),   // session revocation
]);

audit((int)$user['id'], 'login', 'staff', (int)$user['id'], null, (int)$user['home_id']);

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
