<?php
// GET /homes/active.php — the caller's current active home (id + name).
// The JWT carries the active home id; this resolves its name for display.
require __DIR__ . '/../config.php';
$auth = require_auth();

$homeId = (int)($auth['home'] ?? 0);
$companyId = (int)($auth['company'] ?? 0);

$stmt = db()->prepare('SELECT id, name FROM homes WHERE id = ? AND company_id = ?');
$stmt->execute([$homeId, $companyId]);
$home = $stmt->fetch();
if (!$home) fail('Active home not found', 404);

respond([
    'home' => [
        'id'   => (int)$home['id'],
        'name' => $home['name'],
    ],
]);
