<?php
// GET /cqc/provider.php?id=1-XXXXXXXXX  — CQC provider details (trimmed).
require __DIR__ . '/../config.php';
require __DIR__ . '/_cqc.php';
require_auth();

$id = trim($_GET['id'] ?? '');
if ($id === '') fail('id is required');

$r = cqc_get("/providers/$id");
if ($r['status'] === 404) fail('Provider not found at CQC', 404);
if ($r['status'] !== 200) fail('CQC lookup failed (' . ($r['error'] ?? $r['status']) . ')', 502);

$p = $r['data'];
respond(['provider' => [
    'providerId'        => $p['providerId'] ?? $id,
    'name'              => $p['name'] ?? null,
    'registrationStatus'=> $p['registrationStatus'] ?? null,
    'registrationDate'  => $p['registrationDate'] ?? null,
    'type'              => $p['type'] ?? null,
    'postalCode'        => $p['postalCode'] ?? null,
    'locationIds'       => cqc_provider_location_ids($p),
]]);
