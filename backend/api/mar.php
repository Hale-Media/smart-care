<?php
declare(strict_types=1);

/**
 * /api/mar.php — Smart Care medication administration
 *
 * GET  ?resident_id=1            -> today's scheduled doses not yet given
 * POST  administer a dose:
 *   { mar_entry_id?, medication_id?, outcome, notes?,
 *     prn_indication?, prn_followup_mins?,
 *     witness_staff_id?, witness_pin?, cd_quantity? }
 *
 * - mar_entry_id  : administer a scheduled dose (updates that row)
 * - medication_id : ad-hoc dose, typically PRN (inserts a new row)
 * Controlled drugs given require a second signatory (witness_staff_id +
 * witness_pin) and a cd_quantity, and decrement the CD register.
 */

require_once __DIR__ . '/../config.php';
header('Content-Type: application/json');

$jwt  = require_auth();
$repo = new AuditedRepository($pdo, (int) $jwt['sub'], (int) $jwt['home'], $_SERVER['REMOTE_ADDR'] ?? null);

const MAR_OUTCOMES   = ['given','refused','omitted','unavailable','asleep','hospital'];
const WITNESS_ROLES  = ['seniorCarer','nurse','manager','admin'];

try {
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'  => handleDue($pdo, $jwt),
        'POST' => handleAdminister($pdo, $repo, $jwt),
        default => respond(405, ['error' => 'Method not allowed']),
    };
} catch (Throwable $e) {
    respond(500, ['error' => 'Server error', 'detail' => $e->getMessage()]); // strip detail in prod
}

// =====================================================================

function handleDue(PDO $pdo, array $jwt): never
{
    $residentId = (int) ($_GET['resident_id'] ?? 0);
    if ($residentId <= 0) {
        respond(422, ['error' => 'resident_id is required']);
    }
    requireResidentInHome($pdo, $residentId, (int) $jwt['home']);

    $stmt = $pdo->prepare(
        "SELECT e.id, e.medication_id, e.scheduled_for, e.outcome,
                m.name, m.dose, m.route, m.prn, m.controlled_drug, m.prn_reason
         FROM mar_entries e
         JOIN medications m ON m.id = e.medication_id
         WHERE e.resident_id = ? AND e.administered_at IS NULL
           AND DATE(e.scheduled_for) = CURDATE()
         ORDER BY e.scheduled_for"
    );
    $stmt->execute([$residentId]);
    respond(200, ['due' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleAdminister(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    $in      = input();
    $marId   = (int) ($in['mar_entry_id'] ?? 0);
    $medId   = (int) ($in['medication_id'] ?? 0);
    $outcome = (string) ($in['outcome'] ?? 'given');
    $homeId  = (int) $jwt['home'];
    $staffId = (int) $jwt['sub'];

    if (!in_array($outcome, MAR_OUTCOMES, true)) {
        respond(422, ['error' => 'invalid outcome']);
    }

    // Resolve the scheduled entry (if any) and the medication.
    $existing = null;
    if ($marId > 0) {
        $existing = requireOwnedMarEntry($pdo, $marId, $homeId);
        $medId    = (int) $existing['medication_id'];
    }
    if ($medId <= 0) {
        respond(422, ['error' => 'mar_entry_id or medication_id is required']);
    }
    $med = requireOwnedMedication($pdo, $medId, $homeId);
    $residentId = (int) $med['resident_id'];

    $isCD  = (int) $med['controlled_drug'] === 1;
    $isPRN = (int) $med['prn'] === 1;
    $given = $outcome === 'given';

    // ---- controlled-drug second signature (only when actually given) ----
    $witnessId = null; $witnessedAt = null; $cdQty = null; $newBalance = null;
    if ($isCD && $given) {
        $witnessId = (int) ($in['witness_staff_id'] ?? 0);
        $witnessPin = (string) ($in['witness_pin'] ?? '');
        $cdQty = isset($in['cd_quantity']) ? (float) $in['cd_quantity'] : 0.0;
        if ($cdQty <= 0) {
            respond(422, ['error' => 'cd_quantity is required for a controlled drug']);
        }
        verifyWitness($pdo, $witnessId, $witnessPin, $homeId, $staffId);
        $witnessedAt = nowStr();

        // Compute the new register balance; refuse to go negative.
        $prev = currentCdBalance($pdo, $medId);
        $newBalance = round($prev - $cdQty, 2);
        if ($newBalance < 0) {
            respond(409, ['error' => 'insufficient recorded CD stock', 'balance' => $prev]);
        }
    }

    // ---- PRN follow-up scheduling (only when given) ----
    $prnIndication = null; $prnDue = null; $prnEffect = null;
    if ($isPRN && $given) {
        $prnIndication = trim((string) ($in['prn_indication'] ?? (string) ($med['prn_reason'] ?? '')));
        if ($prnIndication === '') {
            respond(422, ['error' => 'prn_indication is required for a PRN medication']);
        }
        $mins   = max(5, (int) ($in['prn_followup_mins'] ?? 60));
        $prnDue = (new DateTimeImmutable('now', new DateTimeZone('UTC')))
                    ->modify("+{$mins} minutes")->format('Y-m-d H:i:s');
        $prnEffect = 'pending';
    }

    // ---- write it all in one transaction ----
    $pdo->beginTransaction();
    try {
        $fields = [
            'administered_at'  => nowStr(),
            'administered_by'  => $staffId,
            'outcome'          => $outcome,
            'notes'            => trim((string) ($in['notes'] ?? '')) ?: null,
            'witness_staff_id' => $witnessId,
            'witnessed_at'     => $witnessedAt,
            'prn_indication'   => $prnIndication,
            'prn_followup_due' => $prnDue,
            'prn_effect'       => $prnEffect,
        ];

        if ($existing !== null) {
            $repo->update('mar_entries', $marId, $fields, 'mar_entry');
            $marEntryId = $marId;
        } else {
            $marEntryId = $repo->insert('mar_entries', array_merge([
                'medication_id' => $medId,
                'resident_id'   => $residentId,
                'scheduled_for' => nowStr(),   // ad-hoc dose
            ], $fields), 'mar_entry');
        }

        if ($isCD && $given) {
            $repo->insert('cd_register', [
                'home_id'          => $homeId,
                'medication_id'    => $medId,
                'resident_id'      => $residentId,
                'entry_type'       => 'administration',
                'quantity'         => -$cdQty,
                'balance_after'    => $newBalance,
                'mar_entry_id'     => $marEntryId,
                'staff_id'         => $staffId,
                'witness_staff_id' => $witnessId,
            ], 'cd_register');
        }

        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) { $pdo->rollBack(); }
        throw $e;
    }

    respond(200, array_filter([
        'mar_entry_id' => $marEntryId,
        'cd_balance'   => $newBalance,
        'prn_followup_due' => $prnDue,
    ], static fn($v) => $v !== null));
}

// =====================================================================
// Helpers
// =====================================================================

function verifyWitness(PDO $pdo, int $witnessId, string $pin, int $homeId, int $administeringStaffId): void
{
    if ($witnessId <= 0 || $pin === '') {
        respond(422, ['error' => 'a controlled drug requires a witness_staff_id and witness_pin']);
    }
    if ($witnessId === $administeringStaffId) {
        respond(422, ['error' => 'the witness must be a different member of staff']);
    }
    $stmt = $pdo->prepare('SELECT id, role, pin_hash FROM staff WHERE id = ? AND home_id = ?');
    $stmt->execute([$witnessId, $homeId]);
    $w = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$w) {
        respond(422, ['error' => 'witness not found in this home']);
    }
    if (!in_array($w['role'], WITNESS_ROLES, true)) {
        respond(403, ['error' => 'witness is not authorised to countersign controlled drugs']);
    }
    if (empty($w['pin_hash']) || !password_verify($pin, $w['pin_hash'])) {
        respond(401, ['error' => 'witness PIN is incorrect']);
    }
}

function currentCdBalance(PDO $pdo, int $medicationId): float
{
    $stmt = $pdo->prepare('SELECT balance_after FROM cd_register WHERE medication_id = ? ORDER BY id DESC LIMIT 1');
    $stmt->execute([$medicationId]);
    $bal = $stmt->fetchColumn();
    return $bal === false ? 0.0 : (float) $bal;
}

function respond(int $code, array $body): never
{
    http_response_code($code);
    echo json_encode($body, JSON_UNESCAPED_UNICODE);
    exit;
}

function input(): array
{
    $raw  = file_get_contents('php://input');
    $data = json_decode($raw !== false && $raw !== '' ? $raw : '[]', true);
    return is_array($data) ? $data : [];
}

function nowStr(): string
{
    return (new DateTimeImmutable('now', new DateTimeZone('UTC')))->format('Y-m-d H:i:s');
}

function requireResidentInHome(PDO $pdo, int $residentId, int $homeId): void
{
    $stmt = $pdo->prepare('SELECT 1 FROM residents WHERE id = ? AND home_id = ? AND active = 1');
    $stmt->execute([$residentId, $homeId]);
    if (!$stmt->fetchColumn()) {
        respond(404, ['error' => 'resident not found in this home']);
    }
}

function requireOwnedMedication(PDO $pdo, int $medId, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT m.* FROM medications m
         JOIN residents r ON r.id = m.resident_id
         WHERE m.id = ? AND r.home_id = ? AND m.active = 1'
    );
    $stmt->execute([$medId, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(404, ['error' => 'medication not found in this home']);
    }
    return $row;
}

function requireOwnedMarEntry(PDO $pdo, int $marId, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT e.* FROM mar_entries e
         JOIN residents r ON r.id = e.resident_id
         WHERE e.id = ? AND r.home_id = ?'
    );
    $stmt->execute([$marId, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(404, ['error' => 'MAR entry not found in this home']);
    }
    if ($row['administered_at'] !== null) {
        respond(409, ['error' => 'this dose has already been recorded']);
    }
    return $row;
}
