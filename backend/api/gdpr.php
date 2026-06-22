<?php
declare(strict_types=1);

/**
 * /api/gdpr.php - Smart Care data-subject rights (UK GDPR)
 *
 * GET  ?resident_id=1                    -> subject access export
 * POST ?resident_id=1&action=restrict    -> restrict processing
 * POST ?resident_id=1&action=unrestrict  -> lift restriction
 * POST ?resident_id=1&action=erase       -> pseudonymise identifiers
 */

require_once __DIR__ . '/config.php';

header('Content-Type: application/json');

$jwt     = require_auth();
$pdo     = db();
$staffId = (int) ($jwt['sub'] ?? $jwt['staff_id'] ?? 0);
$homeId  = (int) ($jwt['home'] ?? $jwt['home_id'] ?? 0);
$repo    = new AuditedRepository($pdo, $staffId, $homeId, $_SERVER['REMOTE_ADDR'] ?? null);

const GDPR_VIEW_ROLES  = ['manager', 'admin'];
const GDPR_ERASE_ROLES = ['admin'];

const REDACT = [
    'first_name'             => 'REDACTED',
    'last_name'              => 'REDACTED',
    'dob'                    => null,
    'room_number'            => null,
    'photo_url'              => null,
    'nhs_number'             => null,
    'address'                => null,
    'consent_representative' => null,
    'gp_name'                => null,
    'next_of_kin'            => null,
    'next_of_kin_phone'      => null,
];

try {
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'  => handleExport($pdo, $staffId, $homeId),
        'POST' => handlePost($pdo, $repo, $staffId, $homeId),
        default => respond(['error' => 'Method not allowed'], 405),
    };
} catch (Throwable $e) {
    respond(['error' => 'Server error', 'detail' => $e->getMessage()], 500);
}

function handleExport(PDO $pdo, int $staffId, int $homeId): never
{
    requireRole($pdo, $staffId, $homeId, GDPR_VIEW_ROLES);
    $residentId = (int) ($_GET['resident_id'] ?? 0);
    if ($residentId <= 0) {
        respond(['error' => 'resident_id is required'], 422);
    }

    $resident = ownedResident($pdo, $residentId, $homeId);
    $export = ['resident' => $resident];

    foreach (tablesWithResidentId($pdo) as $table) {
        if (!preg_match('/^[a-z_][a-z0-9_]*$/', $table)) {
            continue;
        }
        $q = $pdo->prepare(sprintf('SELECT * FROM `%s` WHERE resident_id = ?', $table));
        $q->execute([$residentId]);
        $rows = $q->fetchAll(PDO::FETCH_ASSOC);
        if ($rows) {
            $export[$table] = $rows;
        }
    }

    $a = $pdo->prepare("SELECT * FROM audit_log WHERE entity = 'resident' AND entity_id = ? ORDER BY created_at");
    $a->execute([$residentId]);
    $export['audit_log'] = $a->fetchAll(PDO::FETCH_ASSOC);

    logRequest($pdo, $homeId, $residentId, 'access', $staffId, 'Subject access export generated');

    respond([
        'generated_at' => gmdate('c'),
        'resident_id'  => $residentId,
        'data'         => $export,
    ]);
}

function handlePost(PDO $pdo, AuditedRepository $repo, int $staffId, int $homeId): never
{
    $action     = (string) ($_GET['action'] ?? '');
    $residentId = (int) ($_GET['resident_id'] ?? 0);
    if ($residentId <= 0) {
        respond(['error' => 'resident_id is required'], 422);
    }

    $resident = ownedResident($pdo, $residentId, $homeId);

    switch ($action) {
        case 'restrict':
        case 'unrestrict':
            requireRole($pdo, $staffId, $homeId, GDPR_VIEW_ROLES);
            $flag = $action === 'restrict' ? 1 : 0;
            $repo->update('residents', $residentId, ['processing_restricted' => $flag], 'resident');
            logRequest($pdo, $homeId, $residentId, $flag ? 'restriction' : 'unrestriction', $staffId);
            respond(['resident_id' => $residentId, 'processing_restricted' => $flag]);

        case 'erase':
            requireRole($pdo, $staffId, $homeId, GDPR_ERASE_ROLES);
            $in = json_input();
            if (empty($in['confirm'])) {
                respond(['error' => 'erasure must be explicitly confirmed'], 422);
            }
            if ((int) $resident['active'] === 1) {
                respond([
                    'error' => 'cannot erase an active resident',
                    'hint'  => 'discharge the resident first, or use action=restrict',
                ], 409);
            }
            if (($resident['pseudonymised_at'] ?? null) !== null) {
                respond(['error' => 'this resident has already been pseudonymised'], 409);
            }

            erasePersonalIdentifiers($pdo, $residentId, $homeId);
            audit($staffId, 'gdpr_pseudonymise', 'resident', $residentId);
            logRequest(
                $pdo,
                $homeId,
                $residentId,
                'erasure',
                $staffId,
                'Direct identifiers pseudonymised; clinical records retained per statutory retention'
            );

            respond([
                'resident_id' => $residentId,
                'erased'      => true,
                'note'        => 'Direct identifiers removed. Clinical and audit records retained under statutory retention; review free-text notes manually for residual identifiers.',
            ]);

        default:
            respond(['error' => 'unknown action'], 422);
    }
}

function erasePersonalIdentifiers(PDO $pdo, int $residentId, int $homeId): void
{
    $set  = [];
    $args = [];
    foreach (REDACT as $col => $val) {
        $set[]  = "`$col` = ?";
        $args[] = $val;
    }
    $set[]  = '`pseudonymised_at` = ?';
    $args[] = gmdate('Y-m-d H:i:s');
    $set[]  = '`active` = 0';

    $args[] = $residentId;
    $args[] = $homeId;
    $sql = 'UPDATE `residents` SET ' . implode(', ', $set) . ' WHERE id = ? AND home_id = ?';
    $pdo->prepare($sql)->execute($args);
}

function tablesWithResidentId(PDO $pdo): array
{
    $stmt = $pdo->query(
        "SELECT TABLE_NAME FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'resident_id'
         ORDER BY TABLE_NAME"
    );
    return $stmt->fetchAll(PDO::FETCH_COLUMN);
}

function logRequest(PDO $pdo, int $homeId, int $residentId, string $type, int $staffId, ?string $detail = null): void
{
    $stmt = $pdo->prepare(
        'INSERT INTO gdpr_requests (home_id, resident_id, type, performed_by, detail, created_at)
         VALUES (?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([$homeId, $residentId, $type, $staffId, $detail, gmdate('Y-m-d H:i:s')]);
}

function ownedResident(PDO $pdo, int $residentId, int $homeId): array
{
    $stmt = $pdo->prepare('SELECT * FROM residents WHERE id = ? AND home_id = ?');
    $stmt->execute([$residentId, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'resident not found in this home'], 404);
    }
    return $row;
}

function requireRole(PDO $pdo, int $staffId, int $homeId, array $allowed): void
{
    $stmt = $pdo->prepare('SELECT role FROM staff WHERE id = ? AND home_id = ?');
    $stmt->execute([$staffId, $homeId]);
    $role = $stmt->fetchColumn();
    if ($role === false || !in_array($role, $allowed, true)) {
        respond(['error' => 'this action requires one of: ' . implode(', ', $allowed)], 403);
    }
}
