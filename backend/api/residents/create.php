<?php
// POST /residents/create.php
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();

if (trim($in['first_name'] ?? '') === '' || trim($in['last_name'] ?? '') === '') {
    fail('First and last name are required');
}

$stmt = db()->prepare(
    'INSERT INTO residents
       (home_id, first_name, last_name, dob, room_number, photo_url, nhs_number,
        care_level, address, conditions, allergies, medications, mobility, fall_risk, dnacpr,
        gp_name, next_of_kin, next_of_kin_phone, active)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,1)'
);
// Managers/admins may specify a home_id in the body to create in a different home.
$canSetHome = in_array($auth['role'] ?? '', ['manager', 'admin'], true);
$homeId = (int)$auth['home'];
if ($canSetHome && !empty($in['home_id'])) {
    $reqHome = (int)$in['home_id'];
    $own = db()->prepare('SELECT id FROM homes WHERE id = ? AND company_id = ?');
    $own->execute([$reqHome, (int)($auth['company'] ?? 0)]);
    if ($own->fetch()) $homeId = $reqHome;
}

$stmt->execute([
    $homeId,
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
]);
$id = (int)db()->lastInsertId();
audit((int)$auth['sub'], 'create', 'resident', $id);
respond(['resident' => ['id' => $id] + $in], 201);
