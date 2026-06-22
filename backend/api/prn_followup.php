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

require_once __DIR__ . '/../config.php';
header('Content-Type: application/json');

$jwt  = require_auth();
$repo = new AuditedRepository($pdo, (int) $jwt['sub'], (int) $jwt['home'], $_SERVER['REMOTE_ADDR'] ?? null);

const PRN_EFFECTS = ['effective', 'partial', 'not_effective'];

try {
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'          => handlePending($pdo, $jwt),
        'POST','PUT'   => handleRecord($pdo, $repo, $jwt),
        default        => respond(405, ['error' => 'Method not allowed']),
    };
} catch (Throwable $e) {
    respond(500, ['error' => 'Server error', 'detail' => $e->getMessage()]); // strip detail in prod
}

// =====================================================================

function handlePending(PDO $pdo, array $jwt): never
{
    $residentId = (int) ($_GET['resident_id'] ?? 0);
    if ($residentId <= 0) {
        respond(422, ['error' => 'resident_id is required']);
    }
    requireResidentInHome($pdo, $residentId, (int) $jwt['home']);

    $stmt = $pdo->prepare(
        "SELECT e.id, e.medication_id, e.administered_at, e.prn_indication,
                e.prn_followup_due, m.name, m.dose
         FROM mar_entries e
         JOIN medications m ON m.id = e.medication_id
         WHERE e.resident_id = ? AND e.prn_effect = 'pending'
         ORDER BY e.prn_followup_due"
    );
    $stmt->execute([$residentId]);
    respond(200, ['pending' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleRecord(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    $id = (int) ($_GET['id'] ?? 0);
    $in = input();
    if ($id <= 0) {
        respond(422, ['error' => 'id is required']);
    }
    $effect = (string) ($in['effect'] ?? '');
    if (!in_array($effect, PRN_EFFECTS, true)) {
        respond(422, ['error' => 'effect must be effective, partial or not_effective']);
    }

    $entry = requireOwnedMarEntry($pdo, $id, (int) $jwt['home']);
    if (($entry['prn_effect'] ?? null) !== 'pending') {
        respond(409, ['error' => 'this dose has no pending follow-up']);
    }

    $repo->update('mar_entries', $id, [
        'prn_effect'         => $effect,
        'prn_followup_at'    => nowStr(),
        'prn_followup_by'    => (int) $jwt['sub'],
        'prn_followup_notes' => trim((string) ($in['notes'] ?? '')) ?: null,
    ], 'mar_entry');

    respond(200, ['id' => $id, 'effect' => $effect]);
}

// =====================================================================

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
    return $row;
}
