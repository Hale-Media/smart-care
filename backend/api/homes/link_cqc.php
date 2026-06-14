<?php
// POST /homes/link_cqc.php  { cqc_location_id, home_id? }   (admin only)
// Verifies the CQC location, then stores its id + rating on the home (defaults
// to the caller's active home). Returns the rating.
require __DIR__ . '/../config.php';
require __DIR__ . '/../cqc/_cqc.php';
$auth = require_auth();
if (($auth['role'] ?? '') !== 'admin') fail('Insufficient permissions', 403);

$in = json_input();
$locId = trim($in['cqc_location_id'] ?? '');
$homeId = (int)($in['home_id'] ?? $auth['home'] ?? 0);
$companyId = (int)($auth['company'] ?? 0);
if ($locId === '') fail('cqc_location_id is required');

$own = db()->prepare('SELECT id FROM homes WHERE id = ? AND company_id = ?');
$own->execute([$homeId, $companyId]);
if (!$own->fetch()) fail('Home not found in your company', 403);

$r = cqc_get("/locations/$locId");
if ($r['status'] === 404) fail('Location not found at CQC', 404);
if ($r['status'] !== 200) fail('CQC lookup failed (' . ($r['error'] ?? $r['status']) . ')', 502);

$l = $r['data'];
$ratingData = cqc_overall_rating($l);
$rating = $ratingData['rating'];
$date   = $ratingData['date'];

$stmt = db()->prepare(
    'UPDATE homes SET cqc_location_id = ?, cqc_rating = ?, cqc_rating_date = ? WHERE id = ?'
);
$stmt->execute([$locId, $rating, $date, $homeId]);
audit((int)$auth['sub'], 'link_cqc', 'home', $homeId, $locId);

respond([
    'locationId' => $locId,
    'name'       => $l['name'] ?? null,
    'rating'     => $rating,
    'ratingDate' => $date,
]);
