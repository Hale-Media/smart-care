<?php
// POST /homes/switch.php  { home_id }
// Switch the caller's active home. Requires permission (admin, or can_switch_homes),
// verifies the home belongs to their company, then issues a fresh JWT for it.
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();

$homeId = (int)($in['home_id'] ?? 0);
$companyId = (int)($auth['company'] ?? 0);
$staffId = (int)($auth['sub'] ?? 0);
if ($homeId === 0) fail('home_id is required');

// Authoritative permission check (current DB value, not a stale token).
$p = db()->prepare('SELECT role, can_switch_homes FROM staff WHERE id = ?');
$p->execute([$staffId]);
$me = $p->fetch();
$allowed = $me && ($me['role'] === 'admin' || (int)$me['can_switch_homes'] === 1);
if (!$allowed) fail('You do not have permission to switch homes', 403);

$stmt = db()->prepare('SELECT id, name FROM homes WHERE id = ? AND company_id = ?');
$stmt->execute([$homeId, $companyId]);
$home = $stmt->fetch();
if (!$home) fail('Home not found in your company', 404);

$token = jwt_encode([
    'sub' => $staffId, 'company' => $companyId, 'home' => (int)$home['id'],
    'role' => $auth['role'], 'can_switch' => true,
]);
audit($staffId, 'switch_home', 'home', (int)$home['id']);

respond(['token' => $token, 'home' => ['id' => (int)$home['id'], 'name' => $home['name']]]);
