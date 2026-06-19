<?php
declare(strict_types=1);

/**
 * /api/cd_register.php — Smart Care controlled-drug register
 *
 * GET  ?medication_id=1  -> running balance + the stock ledger
 * POST  record a stock movement (NOT administration — that's mar.php):
 *   { medication_id, entry_type, quantity, witness_staff_id, witness_pin, notes? }
 *   entry_type ∈ receipt | disposal | adjustment | return
 *   quantity is the absolute amount; the sign is derived from entry_type
 *   (receipt/return add, disposal subtract, adjustment uses the signed value).
 *
 * Every movement is two-person witnessed, mirroring a paper CD register.
 */

require_once __DIR__ . '/../config.php';
header('Content-Type: application/json');

$jwt  = require_auth();
$repo = new AuditedRepository($pdo, (int) $jwt['staff_id'], (int) $jwt['home_id'], $_SERVER['REMOTE_ADDR'] ?? null);

const CD_MOVEMENTS  = ['receipt', 'disposal', 'adjustment', 'return'];
const WITNESS_ROLES = ['seniorCarer', 'nurse', 'manager', 'admin'];

try {
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'  => handleLedger($pdo, $jwt),
        'POST' => handleMovement($pdo, $repo, $jwt),
        default => respond(405, ['error' => 'Method not allowed']),
    };
} catch (Throwable $e) {
    respond(500, ['error' => 'Server error', 'detail' => $e->getMessage()]); // strip detail in prod
}

// =====================================================================

function handleLedger(PDO $pdo, array $jwt): never
{
    $medId = (int) ($_GET['medication_id'] ?? 0);
    if ($medId <= 0) {
        respond(422, ['error' => 'medication_id is required']);
    }
    requireOwnedControlledDrug($pdo, $medId, (int) $jwt['home_id']);

    $stmt = $pdo->prepare(
        'SELECT id, entry_type, quantity, balance_after, mar_entry_id,
                staff_id, witness_staff_id, notes, created_at
         FROM cd_register WHERE medication_id = ? ORDER BY id DESC'
    );
    $stmt->execute([$medId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    respond(200, [
        'balance' => $rows[0]['balance_after'] ?? '0.00',
        'ledger'  => $rows,
    ]);
}

function handleMovement(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    $in      = input();
    $medId   = (int) ($in['medication_id'] ?? 0);
    $type    = (string) ($in['entry_type'] ?? '');
    $rawQty  = isset($in['quantity']) ? (float) $in['quantity'] : 0.0;
    $homeId  = (int) $jwt['home_id'];
    $staffId = (int) $jwt['staff_id'];

    if ($medId <= 0) {
        respond(422, ['error' => 'medication_id is required']);
    }
    if (!in_array($type, CD_MOVEMENTS, true)) {
        respond(422, ['error' => 'invalid entry_type']);
    }
    if ($rawQty === 0.0) {
        respond(422, ['error' => 'quantity must be non-zero']);
    }

    $med = requireOwnedControlledDrug($pdo, $medId, $homeId);

    // Derive the signed quantity from the movement type.
    $signed = match ($type) {
        'receipt', 'return' => abs($rawQty),
        'disposal'          => -abs($rawQty),
        'adjustment'        => $rawQty,           // caller supplies the sign
    };

    // Witness required for every CD movement.
    $witnessId  = (int) ($in['witness_staff_id'] ?? 0);
    $witnessPin = (string) ($in['witness_pin'] ?? '');
    verifyWitness($pdo, $witnessId, $witnessPin, $homeId, $staffId);

    $prev    = currentCdBalance($pdo, $medId);
    $balance = round($prev + $signed, 2);
    if ($balance < 0) {
        respond(409, ['error' => 'movement would take the balance below zero', 'balance' => $prev]);
    }

    $id = $repo->insert('cd_register', [
        'home_id'          => $homeId,
        'medication_id'    => $medId,
        'resident_id'      => (int) $med['resident_id'],
        'entry_type'       => $type,
        'quantity'         => $signed,
        'balance_after'    => $balance,
        'staff_id'         => $staffId,
        'witness_staff_id' => $witnessId,
        'notes'            => trim((string) ($in['notes'] ?? '')) ?: null,
    ], 'cd_register');

    respond(201, ['id' => $id, 'balance' => $balance]);
}

// =====================================================================
// Helpers
// =====================================================================

function verifyWitness(PDO $pdo, int $witnessId, string $pin, int $homeId, int $staffId): void
{
    if ($witnessId <= 0 || $pin === '') {
        respond(422, ['error' => 'a witness_staff_id and witness_pin are required']);
    }
    if ($witnessId === $staffId) {
        respond(422, ['error' => 'the witness must be a different member of staff']);
    }
    $stmt = $pdo->prepare('SELECT role, pin_hash FROM staff WHERE id = ? AND home_id = ?');
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

function requireOwnedControlledDrug(PDO $pdo, int $medId, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT m.* FROM medications m
         JOIN residents r ON r.id = m.resident_id
         WHERE m.id = ? AND r.home_id = ? AND m.controlled_drug = 1'
    );
    $stmt->execute([$medId, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(404, ['error' => 'controlled drug not found in this home']);
    }
    return $row;
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
