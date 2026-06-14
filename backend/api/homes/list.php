<?php
// GET /homes/list.php — all homes belonging to the caller's company.
require __DIR__ . '/../config.php';
$auth = require_auth();
$companyId = (int)($auth['company'] ?? 0);

$stmt = db()->prepare(
    'SELECT h.id, h.name, h.created_at,
            (SELECT COUNT(*) FROM residents r WHERE r.home_id = h.id AND r.active = 1) AS resident_count
     FROM homes h WHERE h.company_id = ? ORDER BY h.name'
);
$stmt->execute([$companyId]);
respond(['homes' => $stmt->fetchAll()]);
