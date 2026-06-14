<?php
// POST /companies/link_cqc.php  { cqc_provider_id }   (admin only)
// Verifies the provider with CQC, then stores it against the caller's company.
require __DIR__ . '/../config.php';
require __DIR__ . '/../cqc/_cqc.php';
$auth = require_auth();
if (($auth['role'] ?? '') !== 'admin') fail('Insufficient permissions', 403);

$in = json_input();
$providerId = trim($in['cqc_provider_id'] ?? '');
if ($providerId === '') fail('cqc_provider_id is required');

$r = cqc_get("/providers/$providerId");
if ($r['status'] === 404) fail('Provider not found at CQC', 404);
if ($r['status'] !== 200) fail('CQC lookup failed (' . ($r['error'] ?? $r['status']) . ')', 502);

$p = $r['data'];
$registered = (($p['registrationStatus'] ?? '') === 'Registered');

$stmt = db()->prepare('UPDATE companies SET cqc_provider_id = ? WHERE id = ?');
$stmt->execute([$providerId, (int)($auth['company'] ?? 0)]);
audit((int)$auth['sub'], 'link_cqc', 'company', (int)($auth['company'] ?? 0), $providerId);

respond([
    'registered' => $registered,
    'cqc_provider_id' => $providerId,
    'name' => $p['name'] ?? null,
    'registrationStatus' => $p['registrationStatus'] ?? null,
]);
