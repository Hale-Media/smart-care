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
    care_level=?, address=?, call_frequency=?, call_times=?, conditions=?,
    allergies=?, medications=?, monitoring_methods=?, mobility=?, fall_risk=?,
    nutrition_risk=?, dnacpr=?, monitoring_consent=?, consent_representative=?,
    consent_recorded_at=?, outcome_review_date=?, gp_name=?, next_of_kin=?,
    next_of_kin_phone=?
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
    $in['call_frequency'] ?? 'daily',
    is_array($in['call_times'] ?? null) ? implode(',', $in['call_times']) : ($in['call_times'] ?? null),
    is_array($in['conditions'] ?? null) ? implode(',', $in['conditions']) : ($in['conditions'] ?? null),
    is_array($in['allergies'] ?? null) ? implode(',', $in['allergies']) : ($in['allergies'] ?? null),
    is_array($in['medications'] ?? null) ? implode(',', $in['medications']) : ($in['medications'] ?? null),
    is_array($in['monitoring_methods'] ?? null) ? implode(',', $in['monitoring_methods']) : ($in['monitoring_methods'] ?? null),
    $in['mobility'] ?? 'independent',
    $in['fall_risk'] ?? 'low',
    $in['nutrition_risk'] ?? 'low',
    !empty($in['dnacpr']) ? 1 : 0,
    $in['monitoring_consent'] ?? 'not_required',
    $in['consent_representative'] ?? null,
    $in['consent_recorded_at'] ?? null,
    $in['outcome_review_date'] ?? null,
    $in['gp_name'] ?? null,
    $in['next_of_kin'] ?? null,
    $in['next_of_kin_phone'] ?? null,
    $id, (int)$auth['home'],
]);
audit((int)$auth['sub'], 'update', 'resident', $id);
respond(['resident' => $in]);
