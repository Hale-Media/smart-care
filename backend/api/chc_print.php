<?php
declare(strict_types=1);

/**
 * /api/chc_print.php — printable NHS CHC Checklist (HTML, A4)
 *
 * GET ?id=5  -> a self-contained, print-optimised HTML document of one
 *               completed (or draft) checklist, laid out like the gov.uk form.
 *
 * Feed it to whatever turns HTML into PDF — your existing GDPR renderer,
 * wkhtmltopdf, or browser Print → Save as PDF. No local respond()/input()
 * declared (config.php owns those), so it passes the static check.
 *
 * The official A/B/C descriptor text is Crown copyright (OGL); this prints the
 * SELECTED level + the assessor's recorded evidence, which is the completed
 * record — not the blank descriptors.
 */

require_once __DIR__ . '/config.php';

$jwt    = require_auth();
$pdo    = db();
$homeId = (int) $jwt['home_id'];
$id     = (int) ($_GET['id'] ?? 0);
if ($id <= 0) {
    respond(['error' => 'id is required'], 422);
}

// Tenant-scoped fetch, joined to the resident + home for the header block.
$stmt = $pdo->prepare(
    'SELECT c.*, r.first_name, r.last_name, r.dob, r.nhs_number, r.address,
            r.gp_name, r.room_number, h.name AS home_name,
            s.name AS signed_by_name
     FROM chc_checklists c
     JOIN residents r ON r.id = c.resident_id
     LEFT JOIN homes h ON h.id = c.home_id
     LEFT JOIN staff s ON s.id = c.signed_by
     WHERE c.id = ? AND c.home_id = ? AND c.deleted_at IS NULL'
);
$stmt->execute([$id, $homeId]);
$c = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$c) {
    respond(['error' => 'checklist not found in this home'], 404);
}

$domains = json_decode($c['domains'] ?? 'null', true) ?: [];

// Domain display order + labels; trailing * = priority (one A here refers).
$LABELS = [
    'breathing'             => ['Breathing', true],
    'nutrition'             => ['Nutrition — food and drink', false],
    'continence'            => ['Continence', false],
    'skin'                  => ['Skin (including tissue viability)', false],
    'mobility'              => ['Mobility', false],
    'communication'         => ['Communication', false],
    'psychological'         => ['Psychological and emotional needs', false],
    'cognition'             => ['Cognition', false],
    'behaviour'             => ['Behaviour', true],
    'drug_therapies'        => ['Drug therapies and medication (symptom control)', true],
    'altered_consciousness' => ['Altered states of consciousness', true],
];

$h        = static fn($v) => htmlspecialchars((string) $v, ENT_QUOTES, 'UTF-8');
$fullName = trim(($c['first_name'] ?? '') . ' ' . ($c['last_name'] ?? ''));
$positive = $c['outcome'] === 'positive';
$isDraft  = $c['status'] !== 'completed';
$fmtDate  = static fn($d) => $d ? date('j F Y', strtotime($d)) : '—';

header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<title>CHC Checklist — <?= $h($fullName) ?></title>
<style>
  @page { size: A4; margin: 16mm 14mm; }
  * { box-sizing: border-box; }
  body { font-family: Arial, "Helvetica Neue", sans-serif; color: #1a1a1a; font-size: 11px; line-height: 1.4; margin: 0; }
  h1 { font-size: 18px; margin: 0 0 2px; }
  .sub { color: #555; font-size: 11px; margin-bottom: 14px; }
  .draft { color: #b00; border: 2px solid #b00; padding: 2px 8px; border-radius: 4px; font-weight: bold; letter-spacing: .5px; float: right; }
  table { width: 100%; border-collapse: collapse; }
  .meta td { padding: 3px 6px; border: 1px solid #ccc; vertical-align: top; }
  .meta .lbl { background: #f4f6f7; font-weight: bold; width: 22%; white-space: nowrap; }
  .domains { margin-top: 14px; }
  .domains th, .domains td { border: 1px solid #bbb; padding: 5px 6px; vertical-align: top; }
  .domains th { background: #0b2e33; color: #fff; text-align: left; font-size: 10px; }
  .domains th.lvl, .domains td.lvl { width: 26px; text-align: center; }
  .num { width: 18px; text-align: center; color: #666; }
  .ev { color: #333; font-size: 10px; }
  .ev .none { color: #999; font-style: italic; }
  .box { display: inline-block; width: 16px; height: 16px; line-height: 16px; border: 1px solid #444; border-radius: 3px; text-align: center; font-weight: bold; }
  .box.on { background: #0b2e33; color: #fff; border-color: #0b2e33; }
  .star { color: #b06b00; font-weight: bold; }
  .outcome { margin-top: 14px; border: 2px solid #0b2e33; padding: 10px 12px; border-radius: 6px; }
  .outcome.neg { border-color: #777; }
  .outcome .verdict { font-size: 14px; font-weight: bold; }
  .outcome.pos .verdict { color: #0b2e33; }
  .counts { margin-top: 4px; color: #444; }
  .counts b { display: inline-block; min-width: 1.4em; }
  .sign { margin-top: 16px; }
  .sign td { border: 1px solid #ccc; padding: 6px; height: 40px; vertical-align: top; }
  .foot { margin-top: 14px; color: #666; font-size: 9.5px; border-top: 1px solid #ddd; padding-top: 8px; }
</style>
</head>
<body>

<?php if ($isDraft): ?><span class="draft">DRAFT — NOT SIGNED OFF</span><?php endif; ?>
<h1>NHS Continuing Healthcare — Checklist</h1>
<div class="sub">Screening tool to identify the need for a full assessment of eligibility.</div>

<table class="meta">
  <tr>
    <td class="lbl">Name</td><td><?= $h($fullName ?: '—') ?></td>
    <td class="lbl">Date of birth</td><td><?= $h($fmtDate($c['dob'])) ?></td>
  </tr>
  <tr>
    <td class="lbl">NHS number</td><td><?= $h($c['nhs_number'] ?: '—') ?></td>
    <td class="lbl">GP practice</td><td><?= $h($c['gp_name'] ?: '—') ?></td>
  </tr>
  <tr>
    <td class="lbl">Current location</td><td><?= $h(trim(($c['home_name'] ?? '') . ($c['room_number'] ? ' — Room ' . $c['room_number'] : '')) ?: '—') ?></td>
    <td class="lbl">Address</td><td><?= $h($c['address'] ?: '—') ?></td>
  </tr>
  <tr>
    <td class="lbl">Date of completion</td><td><?= $h($fmtDate($c['completed_at'] ?? $c['created_at'])) ?></td>
    <td class="lbl">Person involved?</td>
    <td><?= $c['person_involved'] ? 'Yes' : 'No' ?><?php if ($c['representative_name']): ?> · Representative: <?= $h($c['representative_name']) ?> (<?= $c['representative_involved'] ? 'involved' : 'not involved' ?>)<?php endif; ?></td>
  </tr>
</table>

<table class="domains">
  <thead>
    <tr>
      <th class="num">#</th>
      <th>Care domain</th>
      <th class="lvl">A</th><th class="lvl">B</th><th class="lvl">C</th>
    </tr>
  </thead>
  <tbody>
  <?php $i = 0; foreach ($LABELS as $key => [$label, $priority]):
        $i++;
        $lvl = $domains[$key]['level'] ?? null;
        $ev  = $domains[$key]['evidence'] ?? null; ?>
    <tr>
      <td class="num"><?= $i ?></td>
      <td><?= $h($label) ?><?php if ($priority): ?> <span class="star" title="priority domain">*</span><?php endif; ?></td>
      <?php foreach (['A','B','C'] as $L): ?>
        <td class="lvl"><span class="box <?= $lvl === $L ? 'on' : '' ?>"><?= $lvl === $L ? $L : '' ?></span></td>
      <?php endforeach; ?>
    </tr>
    <tr>
      <td></td>
      <td colspan="4" class="ev">
        <?php if ($ev): ?><?= nl2br($h($ev)) ?><?php else: ?><span class="none">No evidence recorded.</span><?php endif; ?>
      </td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
<div class="sub" style="margin-top:6px;"><span class="star">*</span> Priority domain — a single <b>A</b> here indicates a referral on its own.</div>

<div class="outcome <?= $positive ? 'pos' : 'neg' ?>">
  <div class="verdict">
    <?= $positive
        ? 'POSITIVE — referral for full assessment is necessary'
        : 'NEGATIVE — no referral for full assessment is necessary' ?>
  </div>
  <div class="counts">Totals — <b>A:</b> <?= (int) $c['count_a'] ?> &nbsp; <b>B:</b> <?= (int) $c['count_b'] ?> &nbsp; <b>C:</b> <?= (int) $c['count_c'] ?></div>
  <?php if (!$positive): ?>
    <div class="counts" style="font-size:10px;">Best practice: send a copy of a negative checklist to the ICB so it is available if the person requests a review.</div>
  <?php endif; ?>
  <?php if (!empty($c['rationale'])): ?>
    <div class="counts" style="margin-top:6px;"><b>Rationale:</b> <?= nl2br($h($c['rationale'])) ?></div>
  <?php endif; ?>
</div>

<table class="sign">
  <tr>
    <td style="width:50%"><b>Assessor</b><br><?= $h($c['assessor_name'] ?: '—') ?></td>
    <td><b>Role</b><br><?= $h($c['assessor_role'] ?: '—') ?></td>
  </tr>
  <tr>
    <td><b>Organisation</b><br><?= $h($c['assessor_org'] ?: '—') ?></td>
    <td><b>Signed / date</b><br><?= $h($c['signed_by_name'] ?: '—') ?> <?= $c['completed_at'] ? '· ' . $h($fmtDate($c['completed_at'])) : '' ?></td>
  </tr>
</table>

<div class="foot">
  A positive checklist does not mean the person is eligible for NHS Continuing Healthcare — it indicates a full assessment is required.
  Generated by Smart Care on <?= $h(date('j F Y, H:i')) ?>. Record ID <?= (int) $c['id'] ?>.
</div>

</body>
</html>
