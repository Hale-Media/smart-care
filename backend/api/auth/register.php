<?php
// POST /auth/register.php
// Public company self-signup. Creates company + first home + admin, returns a JWT.
// Body: { company_name, admin_name, admin_email, password, home_name? }
require __DIR__ . '/../config.php';

$in = json_input();
$companyName = trim($in['company_name'] ?? '');
$adminName   = trim($in['admin_name'] ?? '');
$email       = trim($in['admin_email'] ?? '');
$password    = $in['password'] ?? '';
$homeName    = trim($in['home_name'] ?? '');
if ($homeName === '') $homeName = $companyName . ' — Main Home';

if ($companyName === '' || $adminName === '' || $email === '' || $password === '') {
    fail('Company name, your name, email and password are all required');
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) fail('Enter a valid email address');
if (strlen($password) < 8) fail('Password must be at least 8 characters');

$chk = db()->prepare('SELECT id FROM staff WHERE email = ?');
$chk->execute([$email]);
if ($chk->fetch()) fail('An account with that email already exists', 409);

db()->beginTransaction();
try {
    $slug = strtolower(preg_replace('/[^a-z0-9]+/i', '-', $companyName));
    $slug = trim($slug, '-') . '-' . substr(bin2hex(random_bytes(4)), 0, 6);

    $stmt = db()->prepare('INSERT INTO companies (name, slug, contact_email, plan, status) VALUES (?,?,?,?,?)');
    $stmt->execute([$companyName, $slug, $email, 'starter', 'trial']);
    $companyId = (int)db()->lastInsertId();

    $stmt = db()->prepare('INSERT INTO homes (company_id, name) VALUES (?,?)');
    $stmt->execute([$companyId, $homeName]);
    $homeId = (int)db()->lastInsertId();

    // The founding admin can switch homes by default.
    $stmt = db()->prepare(
        'INSERT INTO staff (company_id, home_id, name, email, password_hash, role, can_switch_homes, on_shift, active)
         VALUES (?,?,?,?,?,?,1,0,1)'
    );
    $stmt->execute([
        $companyId, $homeId, $adminName, $email,
        password_hash($password, PASSWORD_BCRYPT), 'admin',
    ]);
    $staffId = (int)db()->lastInsertId();

    db()->commit();
} catch (Throwable $e) {
    db()->rollBack();
    fail('Registration failed: ' . $e->getMessage(), 500);
}

audit($staffId, 'register', 'company', $companyId, $companyName);

$token = jwt_encode([
    'sub' => $staffId, 'company' => $companyId, 'home' => $homeId,
    'role' => 'admin', 'can_switch' => true,
]);

respond([
    'token' => $token,
    'user'  => [
        'id' => $staffId, 'name' => $adminName, 'email' => $email, 'role' => 'admin',
        'company_id' => $companyId, 'home_id' => $homeId, 'home_name' => $homeName, 'can_switch_homes' => 1,
    ],
    'company' => ['id' => $companyId, 'name' => $companyName, 'plan' => 'starter', 'status' => 'trial'],
], 201);
