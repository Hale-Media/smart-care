<?php
declare(strict_types=1);

/**
 * /api/chc.php — Smart Care NHS Continuing Healthcare Checklist
 *
 * The CHC Checklist is the national screening tool: 11 care domains scored
 * A/B/C. The referral outcome is computed HERE, server-side, from the scores
 * — never trusted from the client — because it drives a funding referral.
 *
 * GET    ?resident_id=1        -> checklists for a resident
 * GET    ?id=5                 -> one checklist (full detail)
 * POST   {resident_id, domains{…}, …}        -> create a draft
 * PUT    ?id=5 {domains{…}, …}                -> update a draft
 * PUT    ?id=5&action=complete {assessor_*}   -> sign off (locks the record)
 * DELETE ?id=5                 -> soft delete (drafts only)
 *
 * Writes require a senior/registered role (the Framework requires a trained
 * practitioner). Reads are tenant-scoped to the home.
 *
 * NOTE: the official A/B/C descriptor text for each domain is Crown copyright
 * (Open Government Licence) — source it from the gov.uk checklist form for the
 * UI. This endpoint stores the selected level + the assessor's own evidence.
 */

require_once __DIR__ . '/config.php';
header('Content-Type: application/json');

$jwt     = require_auth();
$pdo     = db();
$staffId = (int) $jwt['staff_id'];
$homeId  = (int) $jwt['home_id'];
$repo    = new AuditedRepository($pdo, $staffId, $homeId, $_SERVER['REMOTE_ADDR'] ?? null);

// The 11 static care domains, in order. The four marked true carry a
// priority level in the DST — a single 'A' in any of them forces a referral.
const CHC_DOMAINS = [
    'breathing'            => true,
    'nutrition'            => false,
    'continence'           => false,
    'skin'                 => false,
    'mobility'             => false,
    'communication'        => false,
    'psychological'        => false,
    'cognition'            => false,
    'behaviour'            => true,
    'drug_therapies'       => true,
    'altered_consciousness'=> true,
];
const CHC_LEVELS   = ['A', 'B', 'C'];
const SENIOR_ROLES = ['seniorCarer', 'nurse', 'manager', 'admin'];

try {
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'          => isset($_GET['id']) ? handleGetOne($pdo, $homeId) : handleList($pdo, $homeId),
        'POST'         => handleCreate($pdo, $repo, $jwt),
        'PUT', 'PATCH' => (($_GET['action'] ?? '') === 'complete')
                            ? handleComplete($pdo, $repo, $jwt)
                            : handleUpdate($pdo, $repo, $jwt),
        'DELETE'       => handleDelete($pdo, $repo, $jwt),
        default        => respond(['error' => 'Method not allowed'], 405),
    };
} catch (Throwable $e) {
    respond(['error' => 'Server error', 'detail' => $e->getMessage()], 500); // strip detail in prod
}

// =====================================================================
// Outcome computation — the heart of it
// =====================================================================

/**
 * Validate the submitted domains and compute the referral outcome per the
 * National Framework threshold. Returns [domains, count_a, count_b, count_c,
 * outcome]. Throws on invalid input.
 */
function chcCompute(array $domains): array
{
    $clean = [];
    $a = $b = $c = 0;

    foreach (CHC_DOMAINS as $key => $_priority) {
        $entry = $domains[$key] ?? null;
        $level = is_array($entry) ? ($entry['level'] ?? null) : null;
        if (!in_array($level, CHC_LEVELS, true)) {
            respond(['error' => "domain '$key' must be scored A, B or C"], 422);
        }
        $clean[$key] = [
            'level'    => $level,
            'evidence' => trim((string) ($entry['evidence'] ?? '')) ?: null,
        ];
        if ($level === 'A') $a++;
        elseif ($level === 'B') $b++;
        else $c++;
    }

    // Positive (refer) if ANY of the National Framework triggers apply:
    //   • 2+ domains at A
    //   • 5+ domains at B  (or 1 A and 4 B)
    //   • a single A in any priority (asterisked) domain
    $priorityA = false;
    foreach (CHC_DOMAINS as $key => $priority) {
        if ($priority && $clean[$key]['level'] === 'A') { $priorityA = true; break; }
    }
    $positive = ($a >= 2)
             || ($b >= 5)
             || ($a >= 1 && $b >= 4)
             || $priorityA;

    return [$clean, $a, $b, $c, $positive ? 'positive' : 'negative'];
}

// =====================================================================
// Handlers
// =====================================================================

function handleList(PDO $pdo, int $homeId): never
{
    $residentId = (int) ($_GET['resident_id'] ?? 0);
    if ($residentId <= 0) {
        respond(['error' => 'resident_id is required'], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);
    $stmt = $pdo->prepare(
        'SELECT id, status, count_a, count_b, count_c, outcome, completed_at, created_at
         FROM chc_checklists
         WHERE resident_id = ? AND deleted_at IS NULL
         ORDER BY created_at DESC'
    );
    $stmt->execute([$residentId]);
    respond(['checklists' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleGetOne(PDO $pdo, int $homeId): never
{
    $row = requireOwned($pdo, (int) $_GET['id'], $homeId);
    $row['domains'] = json_decode($row['domains'] ?? 'null', true);
    respond(['checklist' => $row]);
}

function handleCreate(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    requireSeniorRole($pdo, (int) $jwt['staff_id'], (int) $jwt['home_id']);
    $in         = input();
    $residentId = (int) ($in['resident_id'] ?? 0);
    if ($residentId <= 0) {
        respond(['error' => 'resident_id is required'], 422);
    }
    requireResidentInHome($pdo, $residentId, (int) $jwt['home_id']);

    [$domains, $a, $b, $c, $outcome] = chcCompute((array) ($in['domains'] ?? []));

    $id = $repo->insert('chc_checklists', [
        'home_id'                 => (int) $jwt['home_id'],
        'resident_id'             => $residentId,
        'status'                  => 'draft',
        'domains'                 => json_encode($domains, JSON_UNESCAPED_UNICODE),
        'count_a'                 => $a,
        'count_b'                 => $b,
        'count_c'                 => $c,
        'outcome'                 => $outcome,
        'rationale'               => trim((string) ($in['rationale'] ?? '')) ?: null,
        'person_involved'         => !empty($in['person_involved']) ? 1 : 0,
        'representative_name'     => trim((string) ($in['representative_name'] ?? '')) ?: null,
        'representative_involved' => !empty($in['representative_involved']) ? 1 : 0,
        'created_by'              => (int) $jwt['staff_id'],
    ], 'chc_checklist');

    respond(['id' => $id, 'outcome' => $outcome, 'count_a' => $a, 'count_b' => $b], 201);
}

function handleUpdate(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    requireSeniorRole($pdo, (int) $jwt['staff_id'], (int) $jwt['home_id']);
    $id  = (int) ($_GET['id'] ?? 0);
    $in  = input();
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    $row = requireOwned($pdo, $id, (int) $jwt['home_id']);
    if ($row['status'] === 'completed') {
        respond(['error' => 'a completed checklist is read-only; create a new one'], 409);
    }

    $data = [];
    if (array_key_exists('domains', $in)) {
        [$domains, $a, $b, $c, $outcome] = chcCompute((array) $in['domains']);
        $data += [
            'domains' => json_encode($domains, JSON_UNESCAPED_UNICODE),
            'count_a' => $a, 'count_b' => $b, 'count_c' => $c, 'outcome' => $outcome,
        ];
    }
    foreach (['rationale', 'representative_name'] as $f) {
        if (array_key_exists($f, $in)) $data[$f] = trim((string) $in[$f]) ?: null;
    }
    foreach (['person_involved', 'representative_involved'] as $f) {
        if (array_key_exists($f, $in)) $data[$f] = !empty($in[$f]) ? 1 : 0;
    }
    if (!$data) {
        respond(['error' => 'no fields to update'], 422);
    }

    $repo->update('chc_checklists', $id, $data, 'chc_checklist');
    respond(['id' => $id, 'outcome' => $data['outcome'] ?? $row['outcome']]);
}

function handleComplete(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    requireSeniorRole($pdo, (int) $jwt['staff_id'], (int) $jwt['home_id']);
    $id = (int) ($_GET['id'] ?? 0);
    $in = input();
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    $row = requireOwned($pdo, $id, (int) $jwt['home_id']);
    if ($row['status'] === 'completed') {
        respond(['error' => 'already completed'], 409);
    }

    $repo->update('chc_checklists', $id, [
        'status'        => 'completed',
        'assessor_name' => trim((string) ($in['assessor_name'] ?? '')) ?: null,
        'assessor_role' => trim((string) ($in['assessor_role'] ?? '')) ?: null,
        'assessor_org'  => trim((string) ($in['assessor_org'] ?? '')) ?: null,
        'completed_at'  => (new DateTimeImmutable('now', new DateTimeZone('UTC')))->format('Y-m-d H:i:s'),
        'signed_by'     => (int) $jwt['staff_id'],
    ], 'chc_checklist');

    respond(['id' => $id, 'status' => 'completed', 'outcome' => $row['outcome']]);
}

function handleDelete(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    requireSeniorRole($pdo, (int) $jwt['staff_id'], (int) $jwt['home_id']);
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    $row = requireOwned($pdo, $id, (int) $jwt['home_id']);
    if ($row['status'] === 'completed') {
        respond(['error' => 'cannot delete a completed checklist'], 409);
    }
    $repo->softDelete('chc_checklists', $id, 'chc_checklist');
    respond(['deleted' => $id]);
}

// =====================================================================
// Helpers
// =====================================================================

function respond($data, int $code = 200): never
{
    http_response_code($code);
    header('Content-Type: application/json');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function input(): array
{
    return json_input();
}

function requireResidentInHome(PDO $pdo, int $residentId, int $homeId): void
{
    $stmt = $pdo->prepare('SELECT 1 FROM residents WHERE id = ? AND home_id = ? AND active = 1');
    $stmt->execute([$residentId, $homeId]);
    if (!$stmt->fetchColumn()) {
        respond(['error' => 'resident not found in this home'], 404);
    }
}

function requireOwned(PDO $pdo, int $id, int $homeId): array
{
    $stmt = $pdo->prepare('SELECT * FROM chc_checklists WHERE id = ? AND home_id = ? AND deleted_at IS NULL');
    $stmt->execute([$id, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'checklist not found in this home'], 404);
    }
    return $row;
}

function requireSeniorRole(PDO $pdo, int $staffId, int $homeId): void
{
    $stmt = $pdo->prepare('SELECT role FROM staff WHERE id = ? AND home_id = ?');
    $stmt->execute([$staffId, $homeId]);
    $role = $stmt->fetchColumn();
    if ($role === false || !in_array($role, SENIOR_ROLES, true)) {
        respond(['error' => 'this action requires a senior/registered role'], 403);
    }
}
