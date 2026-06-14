<?php
// POST /care_calls/confirm.php
// Body: { id, notes?, care_provided?, safety_checked?, wellbeing_status?, escalated_to?, promotes_independence?, review_required? }
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();
$id = (int)($in['id'] ?? 0);
if ($id === 0) fail('id is required');

$allowedStatuses = ['stable', 'physical_change', 'mental_change', 'both'];
$wellbeingStatus = $in['wellbeing_status'] ?? 'stable';
if (!in_array($wellbeingStatus, $allowedStatuses, true)) {
    fail('Invalid wellbeing_status');
}

$stmt = db()->prepare(
    'SELECT cc.id
     FROM care_calls cc
     JOIN residents r ON r.id = cc.resident_id
     WHERE cc.id = ? AND r.home_id = ?'
);
$stmt->execute([$id, (int)$auth['home']]);
if (!$stmt->fetch()) fail('Call not found', 404);

$update = db()->prepare(
    'UPDATE care_calls
     SET confirmed = 1,
         confirmed_at = NOW(),
         confirmed_by = ?,
         notes = ?,
         care_provided = ?,
         safety_checked = ?,
         wellbeing_status = ?,
         escalated_to = ?,
         promotes_independence = ?,
         review_required = ?
     WHERE id = ?'
);
$update->execute([
    (int)$auth['sub'],
    $in['notes'] ?? null,
    $in['care_provided'] ?? null,
    !empty($in['safety_checked']) ? 1 : 0,
    $wellbeingStatus,
    $in['escalated_to'] ?? null,
    !empty($in['promotes_independence']) ? 1 : 0,
    !empty($in['review_required']) ? 1 : 0,
    $id,
]);

$read = db()->prepare(
    'SELECT cc.*, CONCAT(r.first_name, " ", r.last_name) AS resident_name,
            s.name AS confirmed_by_name
     FROM care_calls cc
     JOIN residents r ON r.id = cc.resident_id
     LEFT JOIN staff s ON s.id = cc.confirmed_by
     WHERE cc.id = ?'
);
$read->execute([$id]);
$call = $read->fetch();

audit((int)$auth['sub'], 'confirm', 'care_call', $id, $wellbeingStatus);
respond(['call' => $call]);