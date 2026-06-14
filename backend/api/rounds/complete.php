<?php
// POST /rounds/complete.php
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();
$id = (int)($in['id'] ?? 0);
if ($id === 0) fail('id is required');

// Verify the round belongs to this home via resident → home_id
$check = db()->prepare(
    "SELECT cr.id FROM care_rounds cr
     JOIN residents r ON r.id = cr.resident_id
     WHERE cr.id = ? AND r.home_id = ?"
);
$check->execute([$id, (int)$auth['home']]);
if (!$check->fetch()) fail('Round not found', 404);

$staffId = (int)$auth['sub'];
$completedAt = $in['completed_at'] ?? date('Y-m-d H:i:s');

$stmt = db()->prepare(
    "UPDATE care_rounds
     SET completed_at = ?, completed_by = ?, observation = ?, position = ?, notes = ?
     WHERE id = ?"
);
$stmt->execute([
    $completedAt,
    $staffId,
    $in['observation'] ?? null,
    $in['position'] ?? null,
    $in['notes'] ?? null,
    $id,
]);

audit($staffId, 'complete', 'round', $id, $in['observation'] ?? null);

$row = db()->prepare(
    "SELECT cr.*, CONCAT(r.first_name,' ',r.last_name) AS resident_name,
            s.name AS completed_by_name
     FROM care_rounds cr
     JOIN residents r ON r.id = cr.resident_id
     LEFT JOIN staff s ON s.id = cr.completed_by
     WHERE cr.id = ?"
);
$row->execute([$id]);
respond(['round' => $row->fetch()]);
