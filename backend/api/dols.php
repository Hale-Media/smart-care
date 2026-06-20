<?php
declare(strict_types=1);

/**
 * /api/dols.php — Smart Care DoLS authorisations
 *
 * GET    ?resident_id=1   -> all DoLS records for a resident
 * GET    ?expiring=30     -> granted DoLS in the home expiring within N days
 * POST   {resident_id, status, ...}   -> create
 * PUT    ?id=5 {...}      -> update
 * DELETE ?id=5           -> soft delete
 *
 * Writes go through AuditedRepository (before/after trail) and require a
 * senior role. config.php autoloads AuditedRepository from ./lib.
 */

require_once __DIR__ . '/config.php';
header('Content-Type: application/json');

$jwt     = require_auth();
$pdo     = db();
$staffId = (int) $jwt['sub'];
$homeId  = (int) $jwt['home'];
$repo    = new AuditedRepository($pdo, $staffId, $homeId, $_SERVER['REMOTE_ADDR'] ?? null);

const DOLS_STATUSES = ['not_required','urgent','applied','granted','declined','expired','ended'];
const DOLS_FIELDS   = ['status','urgent','reference','supervisory_body','applied_on','granted_on','expires_on','conditions','notes'];
const SENIOR_ROLES  = ['seniorCarer','nurse','manager','admin'];

try {
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'          => isset($_GET['expiring']) ? handleExpiring($pdo, $homeId) : handleGet($pdo, $homeId),
        'POST'         => handleCreate($pdo, $repo, $jwt, $homeId),
        'PUT', 'PATCH' => handleUpdate($pdo, $repo, $jwt, $homeId),
        'DELETE'       => handleDelete($pdo, $repo, $jwt, $homeId),
        default        => respond(['error' => 'Method not allowed'], 405),
    };
} catch (Throwable $e) {
    respond(['error' => 'Server error', 'detail' => $e->getMessage()], 500); // strip detail in prod
}

function requireSenior(array $jwt): void {
    if (!in_array($jwt['role'] ?? '', SENIOR_ROLES, true)) {
        respond(['error' => 'this action requires a senior role'], 403);
    }
}

function requireResidentInHome(PDO $pdo, int $residentId, int $homeId): void {
    $stmt = $pdo->prepare('SELECT 1 FROM residents WHERE id = ? AND home_id = ? AND active = 1');
    $stmt->execute([$residentId, $homeId]);
    if (!$stmt->fetchColumn()) {
        respond(['error' => 'resident not found in this home'], 404);
    }
}

function requireOwnedDols(PDO $pdo, int $id, int $homeId): array {
    $stmt = $pdo->prepare(
        'SELECT d.* FROM dols_authorisations d
         JOIN residents r ON r.id = d.resident_id
         WHERE d.id = ? AND r.home_id = ? AND d.deleted_at IS NULL'
    );
    $stmt->execute([$id, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'DoLS record not found'], 404);
    }
    return $row;
}

function pick(array $in, array $fields): array {
    $out = [];
    foreach ($fields as $f) {
        if (array_key_exists($f, $in)) {
            if ($f === 'urgent') { $out[$f] = $in[$f] ? 1 : 0; continue; }
            $v = $in[$f];
            $out[$f] = (is_string($v) && trim($v) === '') ? null : $v;
        }
    }
    return $out;
}

function handleGet(PDO $pdo, int $homeId): never {
    $residentId = (int) ($_GET['resident_id'] ?? 0);
    if ($residentId <= 0) {
        respond(['error' => 'resident_id is required'], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);
    $stmt = $pdo->prepare(
        'SELECT * FROM dols_authorisations
         WHERE resident_id = ? AND deleted_at IS NULL
         ORDER BY COALESCE(applied_on, DATE(created_at)) DESC'
    );
    $stmt->execute([$residentId]);
    respond(['dols' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleExpiring(PDO $pdo, int $homeId): never {
    $days = max(1, (int) $_GET['expiring']);
    $stmt = $pdo->prepare(
        "SELECT d.*, r.first_name, r.last_name
         FROM dols_authorisations d
         JOIN residents r ON r.id = d.resident_id
         WHERE d.home_id = ? AND d.deleted_at IS NULL AND d.status = 'granted'
           AND d.expires_on IS NOT NULL
           AND d.expires_on <= DATE_ADD(CURDATE(), INTERVAL ? DAY)
         ORDER BY d.expires_on"
    );
    $stmt->execute([$homeId, $days]);
    respond(['expiring' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(PDO $pdo, AuditedRepository $repo, array $jwt, int $homeId): never {
    requireSenior($jwt);
    $in         = input_body();
    $residentId = (int) ($in['resident_id'] ?? 0);
    $status     = (string) ($in['status'] ?? '');

    $errors = [];
    if ($residentId <= 0)                        $errors[] = 'resident_id is required';
    if (!in_array($status, DOLS_STATUSES, true)) $errors[] = 'invalid status';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    $row = ['home_id' => $homeId, 'resident_id' => $residentId, 'recorded_by' => (int) $jwt['sub']];
    $row += pick($in, DOLS_FIELDS);
    $row['status'] = $status;
    $row['urgent'] = !empty($in['urgent']) ? 1 : 0;

    $id = $repo->insert('dols_authorisations', $row, 'dols_authorisation');
    respond(['id' => $id], 201);
}

function handleUpdate(PDO $pdo, AuditedRepository $repo, array $jwt, int $homeId): never {
    requireSenior($jwt);
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedDols($pdo, $id, $homeId);
    $in = input_body();

    if (isset($in['status']) && !in_array($in['status'], DOLS_STATUSES, true)) {
        respond(['error' => 'invalid status'], 422);
    }
    $data = pick($in, DOLS_FIELDS);
    if (!$data) {
        respond(['error' => 'no fields to update'], 422);
    }
    $repo->update('dols_authorisations', $id, $data, 'dols_authorisation');
    respond(['updated' => $id]);
}

function handleDelete(PDO $pdo, AuditedRepository $repo, array $jwt, int $homeId): never {
    requireSenior($jwt);
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedDols($pdo, $id, $homeId);
    $repo->softDelete('dols_authorisations', $id, 'dols_authorisation');
    respond(['deleted' => $id]);
}

function input_body(): array {
    return json_input();
}
