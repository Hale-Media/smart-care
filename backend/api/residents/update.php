<?php
// PUT /residents/update.php
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();
$id = (int)($in['id'] ?? 0);
if ($id === 0) fail('id is required');

$stmt = db()->prepare(
    'UPDATE residents SET
       first_name=?, last_name=?, dob=?, room_number=?, photo_url=?, nhs_number=?,
       care_level=?, address=?, conditions=?, allergies=?, medications=?, mobility=?, fall_risk=?, dnacpr=?,
       gp_name=?, next_of_kin=?, next_of_kin_phone=?
     WHERE id=? AND home_id=?'
);
$stmt->execute([
    $in['first_name'], $in['last_name'],
    $in['dob'] ?? null,
    $in['room_number'] ?? null,
    $in['photo_url'] ?? null,
    $in['nhs_number'] ?? null,
    $in['care_level'] ?? 'residential',
    $in['address'] ?? null,
    is_array($in['conditions'] ?? null) ? implode(',', $in['conditions']) : ($in['conditions'] ?? null),
    is_array($in['allergies'] ?? null) ? implode(',', $in['allergies']) : ($in['allergies'] ?? null),
    is_array($in['medications'] ?? null) ? implode(',', $in['medications']) : ($in['medications'] ?? null),
    $in['mobility'] ?? 'independent',
    $in['fall_risk'] ?? 'low',
    !empty($in['dnacpr']) ? 1 : 0,
    $in['gp_name'] ?? null,
    $in['next_of_kin'] ?? null,
    $in['next_of_kin_phone'] ?? null,
    $id, (int)$auth['home'],
]);
audit((int)$auth['sub'], 'update', 'resident', $id);
respond(['resident' => $in]);
