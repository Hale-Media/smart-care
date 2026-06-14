<?php
// POST /homes/create.php  (manager/admin only)
// Body: { name, address? }
require __DIR__ . '/../config.php';
$auth = require_auth();

if (!in_array($auth['role'] ?? '', ['manager', 'admin'], true)) {
    fail('Insufficient permissions', 403);
}

$in = json_input();
$name    = trim($in['name'] ?? '');
$address = trim($in['address'] ?? '');
$companyId = (int)($auth['company'] ?? 0);

if ($name === '') fail('Home name is required');

$stmt = db()->prepare('INSERT INTO homes (company_id, name, address) VALUES (?,?,?)');
$stmt->execute([$companyId, $name, $address ?: null]);
$id = (int)db()->lastInsertId();
audit((int)$auth['sub'], 'create', 'home', $id, $name);

respond(['home' => ['id' => $id, 'name' => $name, 'resident_count' => 0]], 201);
