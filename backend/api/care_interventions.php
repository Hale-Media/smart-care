<?php
declare(strict_types=1);

/**
 * /api/care_interventions.php — Smart Care
 *
 * An intervention is a planned action ("reposition every 2h") that belongs
 * to a care plan section and is justified by a risk assessment. This is the
 * table that lets a completed round / logged incident trace back to the
 * care plan and the risk that required it.
 *
 * GET    ?resident_id=1                 -> active interventions (with context)
 * GET    ?resident_id=1&all=1           -> include stopped ones
 * POST   {resident_id, section_id, description, risk_assessment_id?, frequency?}  (senior+ only)
 * PUT    ?id=5 {description?, frequency?, status?, risk_assessment_id?}            (senior+ only)
 * DELETE ?id=5                          -> soft delete  (senior+ only)
 *
 * NOTE: not a versioned table — interventions use a status lifecycle
 * (active -> stopped), so this uses insert/update, NOT supersede.
 */

require_once __DIR__ . '/config.php';

header('Content-Type: application/json');

$jwt     = require_auth();
$pdo     = db();
$staffId = (int) $jwt['staff_id'];
$homeId  = (int) $jwt['home_id'];
$repo    = new AuditedRepository($pdo, $staffId, $homeId, $_SERVER['REMOTE_ADDR'] ?? null);

const INTERVENTION_STATUSES = ['active', 'stopped'];

try {
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'          => handleGet($pdo, $homeId),
        'POST'         => handleCreate($pdo, $repo, $staffId, $homeId, $jwt),
        'PUT', 'PATCH' => handleUpdate($pdo, $repo, $homeId, $jwt),
        'DELETE'       => handleDelete($pdo, $repo, $homeId, $jwt),
        default        => respond(['error' => 'Method not allowed'], 405),
    };
} catch (Throwable $e) {
    respond(['error' => 'Server error', 'detail' => $e->getMessage()], 500);
}

// =====================================================================
// Handlers
// =====================================================================

function handleGet(PDO $pdo, int $homeId): never
{
    $residentId = (int) ($_GET['resident_id'] ?? 0);
    if ($residentId <= 0) {
        respond(['error' => 'resident_id is required'], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);

    // Join in the section + risk context so the app can render a useful
    // label ("Reposition 2h — skin / Waterlow high") without extra calls.
    $sql = "SELECT i.*,
                   s.title      AS section_title,
                   s.domain     AS section_domain,
                   a.type       AS risk_type,
                   a.risk_level AS risk_level
            FROM care_interventions i
            JOIN care_plan_sections s ON s.id = i.section_id
            LEFT JOIN risk_assessments a ON a.id = i.risk_assessment_id
            WHERE i.resident_id = ? AND i.deleted_at IS NULL";
    if (empty($_GET['all'])) {
        $sql .= " AND i.status = 'active'";
    }
    $sql .= ' ORDER BY i.created_at DESC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute([$residentId]);
    respond(['interventions' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(PDO $pdo, AuditedRepository $repo, int $staffId, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $in          = json_input();
    $residentId  = (int) ($in['resident_id'] ?? 0);
    $sectionId   = (int) ($in['section_id'] ?? 0);
    $description = trim((string) ($in['description'] ?? ''));
    $riskId      = isset($in['risk_assessment_id']) ? (int) $in['risk_assessment_id'] : null;

    $errors = [];
    if ($residentId <= 0)    $errors[] = 'resident_id is required';
    if ($sectionId <= 0)     $errors[] = 'section_id is required';
    if ($description === '') $errors[] = 'description is required';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }

    requireResidentInHome($pdo, $residentId, $homeId);
    requireSectionForResident($pdo, $sectionId, $residentId, $homeId);
    if ($riskId !== null) {
        requireAssessmentForResident($pdo, $riskId, $residentId, $homeId);
    }

    $id = $repo->insert('care_interventions', [
        'home_id'            => $homeId,
        'resident_id'        => $residentId,
        'section_id'         => $sectionId,
        'risk_assessment_id' => $riskId,
        'description'        => $description,
        'frequency'          => trim((string) ($in['frequency'] ?? '')) ?: null,
        'status'             => 'active',
        'created_by'         => $staffId,
    ], 'care_intervention');

    respond(['id' => $id], 201);
}

function handleUpdate(PDO $pdo, AuditedRepository $repo, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $id = (int) ($_GET['id'] ?? 0);
    $in = json_input();
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    $existing = requireOwnedIntervention($pdo, $id, $homeId);

    $data = [];
    if (array_key_exists('description', $in)) {
        $desc = trim((string) $in['description']);
        if ($desc === '') {
            respond(['error' => 'description cannot be empty'], 422);
        }
        $data['description'] = $desc;
    }
    if (array_key_exists('frequency', $in)) {
        $data['frequency'] = trim((string) $in['frequency']) ?: null;
    }
    if (array_key_exists('status', $in)) {
        if (!in_array($in['status'], INTERVENTION_STATUSES, true)) {
            respond(['error' => 'invalid status', 'valid' => INTERVENTION_STATUSES], 422);
        }
        $data['status'] = $in['status'];
    }
    if (array_key_exists('risk_assessment_id', $in)) {
        $riskId = $in['risk_assessment_id'] === null ? null : (int) $in['risk_assessment_id'];
        if ($riskId !== null) {
            requireAssessmentForResident($pdo, $riskId, (int) $existing['resident_id'], $homeId);
        }
        $data['risk_assessment_id'] = $riskId;
    }

    if (!$data) {
        respond(['error' => 'no updatable fields supplied'], 422);
    }

    $repo->update('care_interventions', $id, $data, 'care_intervention');
    respond(['id' => $id]);
}

function handleDelete(PDO $pdo, AuditedRepository $repo, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedIntervention($pdo, $id, $homeId);
    $repo->softDelete('care_interventions', $id, 'care_intervention');
    respond(['deleted' => $id]);
}

// =====================================================================
// Helpers
// =====================================================================

function requireResidentInHome(PDO $pdo, int $residentId, int $homeId): void
{
    $stmt = $pdo->prepare('SELECT 1 FROM residents WHERE id = ? AND home_id = ? AND active = 1');
    $stmt->execute([$residentId, $homeId]);
    if (!$stmt->fetchColumn()) {
        respond(['error' => 'resident not found in this home'], 404);
    }
}

function requireSectionForResident(PDO $pdo, int $sectionId, int $residentId, int $homeId): void
{
    $stmt = $pdo->prepare(
        'SELECT 1 FROM care_plan_sections
         WHERE id = ? AND resident_id = ? AND home_id = ? AND deleted_at IS NULL'
    );
    $stmt->execute([$sectionId, $residentId, $homeId]);
    if (!$stmt->fetchColumn()) {
        respond(['error' => 'section_id does not belong to this resident'], 422);
    }
}

function requireAssessmentForResident(PDO $pdo, int $assessmentId, int $residentId, int $homeId): void
{
    $stmt = $pdo->prepare(
        'SELECT 1 FROM risk_assessments
         WHERE id = ? AND resident_id = ? AND home_id = ? AND deleted_at IS NULL'
    );
    $stmt->execute([$assessmentId, $residentId, $homeId]);
    if (!$stmt->fetchColumn()) {
        respond(['error' => 'risk_assessment_id does not belong to this resident'], 422);
    }
}

function requireOwnedIntervention(PDO $pdo, int $id, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT i.* FROM care_interventions i
         JOIN residents r ON r.id = i.resident_id
         WHERE i.id = ? AND r.home_id = ? AND i.deleted_at IS NULL'
    );
    $stmt->execute([$id, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'intervention not found in this home'], 404);
    }
    return $row;
}
