<?php
// GET /homes/cqc.php[?home_id=&refresh=1] — the home's linked CQC rating.
require __DIR__ . '/../config.php';
require __DIR__ . '/../cqc/_cqc.php';
$auth = require_auth();

$homeId = (int)($_GET['home_id'] ?? $auth['home'] ?? 0);
$companyId = (int)($auth['company'] ?? 0);
$refresh = ($_GET['refresh'] ?? '') === '1';

$stmt = db()->prepare(
    'SELECT name, cqc_location_id, cqc_rating, cqc_rating_date
     FROM homes WHERE id = ? AND company_id = ?'
);
$stmt->execute([$homeId, $companyId]);
$home = $stmt->fetch();
if (!$home) fail('Home not found', 404);

$locId = $home['cqc_location_id'];
if (!$locId) respond(['linked' => false]);

$rating = $home['cqc_rating'];
$date   = $home['cqc_rating_date'];

if ($refresh) {
    $r = cqc_get("/locations/$locId");
    if ($r['status'] === 200) {
        $l = $r['data'];
        $rating = $l['currentRatings']['overall']['rating'] ?? null;
        $date   = $l['currentRatings']['overall']['reportDate'] ?? null;
        $u = db()->prepare('UPDATE homes SET cqc_rating = ?, cqc_rating_date = ? WHERE id = ?');
        $u->execute([$rating, $date, $homeId]);
    }
}

respond([
    'linked'     => true,
    'locationId' => $locId,
    'rating'     => $rating,
    'ratingDate' => $date,
    'homeName'   => $home['name'],
]);
