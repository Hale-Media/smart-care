<?php
declare(strict_types=1);

/**
 * /api/prn_followup.php — Smart Care PRN effectiveness follow-up
 *
 * GET  ?resident_id=1   -> PRN doses given and awaiting an effectiveness check
 * POST ?id=42 { effect, notes? }   -> record the follow-up
 *   effect ∈ effective | partial | not_effective
 *
 * Closes the PRN loop CQC looks for: a PRN wasn't just given, someone
 * checked whether it worked.
 */

require_once __DIR__ . '/config.php';

$jwt  = require_auth();
$repo = new AuditedRepository(db(), (int) $jwt['staff_id'], (int) $jwt['home_id'], $_SERVER['REMOTE_ADDR'] ?? null);

const PRN_EFFECTS = ['effective', 'partial', 'not_effective'];

try {
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'        => handlePending(db(), $jwt),
        'POST','PUT' => handleRecord(db(), $repo, $jwt),
        default      => respond(['error' => 'Method not allowed'], 405),
    };
} catch (Throwable $e) {
    respond(['error' => 'Server error', 'detail' => $e->getMessage()], 500);
}

// =====================================================================

function handlePending(PDO $pdo, array $jwt): never
{
    $residentId = (int) ($_GET['resident_id'] ?? 0);
    if ($residentId <= 0) {
        respond(['error' => 'resident_id is required'], 422);
    }
    requireResidentInHome($pdo, $residentId, (int) $jwt['home_id']);

    $stmt = $pdo->prepare(
        "SELECT e.id, e.medication_id, e.administered_at, e.prn_indication,
                e.prn_followup_due, m.name, m.dose
         FROM mar_entries e
         JOIN medications m ON m.id = e.medication_id
         WHERE e.resident_id = ? AND e.prn_effect = 'pending'
         ORDER BY e.prn_followup_due"
    );
    $stmt->execute([$residentId]);
    respond(['pending' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleRecord(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    $id = (int) ($_GET['id'] ?? 0);
    $in = json_input();
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    $effect = (string) ($in['effect'] ?? '');
    if (!in_array($effect, PRN_EFFECTS, true)) {
        respond(['error' => 'effect must be effective, partial or not_effective'], 422);
    }

    $entry = requireOwnedMarEntry($pdo, $id, (int) $jwt['home_id']);
    if (($entry['prn_effect'] ?? null) !== 'pending') {
        respond(['error' => 'this dose has no pending follow-up'], 409);
    }

    $repo->update('mar_entries', $id, [
        'prn_effect'         => $effect,
        'prn_followup_at'    => prnNowStr(),
        'prn_followup_by'    => (int) $jwt['staff_id'],
        'prn_followup_notes' => trim((string) ($in['notes'] ?? '')) ?: null,
    ], 'mar_entry');

    respond(['id' => $id, 'effect' => $effect]);
}

// =====================================================================

function prnNowStr(): string
{
    return (new DateTimeImmutable('now', new DateTimeZone('UTC')))->format('Y-m-d H:i:s');
}

function requireResidentInHome(PDO $pdo, int $residentId, int $homeId): void
{
    $stmt = $pdo->prepare('SELECT 1 FROM residents WHERE id = ? AND home_id = ? AND active = 1');
    $stmt->execute([$residentId, $homeId]);
    if (!$stmt->fetchColumn()) {
        respond(['error' => 'resident not found in this home'], 404);
    }
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
        respond(['error' => 'MAR entry not found in this home'], 404);
    }
    return $row;
}
