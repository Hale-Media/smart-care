<?php
// GET /cqc/location.php?id=1-XXXXXXXXX — CQC location details incl. rating.
require __DIR__ . '/../config.php';
require __DIR__ . '/_cqc.php';
require_auth();

$id = trim($_GET['id'] ?? '');
if ($id === '') fail('id is required');

$r = cqc_get("/locations/$id");
if ($r['status'] === 404) fail('Location not found at CQC', 404);
if ($r['status'] !== 200) fail('CQC lookup failed (' . ($r['error'] ?? $r['status']) . ')', 502);

$l = $r['data'];
$rating = cqc_overall_rating($l);
respond(['location' => [
    'locationId'        => $l['locationId'] ?? $id,
    'name'              => $l['name'] ?? null,
    'registrationStatus'=> $l['registrationStatus'] ?? null,
    'postalCode'        => $l['postalCode'] ?? null,
    'numberOfBeds'      => $l['numberOfBeds'] ?? null,
    'providerId'        => $l['providerId'] ?? null,
    'overallRating'     => $rating['rating'],
    'ratingDate'        => $rating['date'],
    'latitude'          => $l['onspdLatitude'] ?? null,
    'longitude'         => $l['onspdLongitude'] ?? null,
    '_debug_ratings'    => $l['currentRatings'] ?? 'KEY_MISSING',
]]);
