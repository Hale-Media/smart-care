<?php
// GET /cqc/verify.php?provider_id=1-XXXXXXXXX
// Confirms registration and returns the provider's locations with ratings.
require __DIR__ . '/../config.php';
require __DIR__ . '/_cqc.php';
require_auth();

$id = trim($_GET['provider_id'] ?? '');
if ($id === '') fail('provider_id is required');

$r = cqc_get("/providers/$id");
if ($r['status'] === 404) {
    respond(['registered' => false, 'provider' => null, 'locations' => []]);
}
if ($r['status'] !== 200) fail('CQC lookup failed (' . ($r['error'] ?? $r['status']) . ')', 502);

$p = $r['data'];
$registered = (($p['registrationStatus'] ?? '') === 'Registered');

$locations = [];
$ids = cqc_provider_location_ids($p);
foreach (array_slice($ids, 0, 25) as $lid) { // cap to stay snappy
    $lr = cqc_get("/locations/$lid");
    if ($lr['status'] !== 200) continue;
    $l = $lr['data'];
    $locations[] = [
        'locationId'        => $l['locationId'] ?? $lid,
        'name'              => $l['name'] ?? null,
        'registrationStatus'=> $l['registrationStatus'] ?? null,
        'postalCode'        => $l['postalCode'] ?? null,
        'overallRating'     => $l['currentRatings']['overall']['rating'] ?? null,
        'ratingDate'        => $l['currentRatings']['overall']['reportDate'] ?? null,
    ];
}

respond([
    'registered' => $registered,
    'provider' => [
        'providerId'         => $p['providerId'] ?? $id,
        'name'               => $p['name'] ?? null,
        'registrationStatus' => $p['registrationStatus'] ?? null,
        'registrationDate'   => $p['registrationDate'] ?? null,
        'type'               => $p['type'] ?? null,
        'postalCode'         => $p['postalCode'] ?? null,
        'locationCount'      => count($ids),
    ],
    'locations' => $locations,
]);
