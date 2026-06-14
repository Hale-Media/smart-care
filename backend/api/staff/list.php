<?php
// GET /staff/list.php — staff in the caller's company (managers/admins only).
require __DIR__ . '/../config.php';
$auth = require_auth();
if (!in_array($auth['role'] ?? '', ['admin', 'manager'], true)) {
    fail('Insufficient permissions', 403);
}

$stmt = db()->prepare(
    'SELECT s.id, s.name, s.email, s.role, s.can_switch_homes, s.home_id, s.active,
            h.name AS home_name
     FROM staff s
     LEFT JOIN homes h ON h.id = s.home_id
     WHERE s.company_id = ?
     ORDER BY s.name'
);
$stmt->execute([(int)($auth['company'] ?? 0)]);
respond(['staff' => $stmt->fetchAll()]);
