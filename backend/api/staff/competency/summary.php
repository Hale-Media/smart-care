<?php
// GET /staff/competency/summary.php
// Returns competency record counts for every active staff member in the caller's company.
require __DIR__ . '/../../config.php';
$auth = require_auth();
if (!in_array($auth['role'] ?? '', ['manager', 'admin', 'nurse', 'seniorCarer'], true)) {
    fail('Insufficient permissions', 403);
}

$companyId = (int)($auth['company'] ?? 0);
$today     = (new DateTimeImmutable())->format('Y-m-d');
$soon      = (new DateTimeImmutable('+30 days'))->format('Y-m-d');

try {
    $stmt = db()->prepare(
        "SELECT s.id, s.name, s.role,
                COUNT(scr.id)                                                          AS total,
                COALESCE(SUM(scr.outcome = 'passed'
                    AND (scr.expiry_date IS NULL OR scr.expiry_date >= ?)), 0)         AS valid,
                COALESCE(SUM(scr.expiry_date IS NOT NULL AND scr.expiry_date < ?), 0) AS expired,
                COALESCE(SUM(scr.expiry_date IS NOT NULL
                    AND scr.expiry_date >= ? AND scr.expiry_date < ?), 0)             AS expiring
         FROM staff s
         LEFT JOIN staff_competency_records scr ON scr.staff_id = s.id
         WHERE s.company_id = ? AND s.active = 1
         GROUP BY s.id, s.name, s.role
         ORDER BY s.name"
    );
    $stmt->execute([$today, $today, $today, $soon, $companyId]);
    $rows = $stmt->fetchAll();
} catch (PDOException $e) {
    if (in_array($e->getCode(), ['42S02', '42S22'], true)) {
        $fallback = db()->prepare(
            'SELECT id, name, role FROM staff WHERE company_id = ? AND active = 1 ORDER BY name'
        );
        $fallback->execute([$companyId]);
        $rows = array_map(fn($r) => $r + ['total' => 0, 'valid' => 0, 'expired' => 0, 'expiring' => 0],
            $fallback->fetchAll());
    } else {
        throw $e;
    }
}

respond(['staff' => $rows]);
