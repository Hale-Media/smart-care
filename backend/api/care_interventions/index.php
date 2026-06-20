<?php
declare(strict_types=1);

/**
 * /api/care_interventions/index.php — Smart Care
 *
 * GET    ?resident_id=1              -> active interventions for resident
 * GET    ?resident_id=1&section_id=3 -> filter by care plan section
 * POST   {resident_id, section_id, description, frequency?, risk_assessment_id?}  (senior+ only)
 * PUT    ?id=5 {description?, frequency?, status?}  (senior+ only)
 * DELETE ?id=5                                       -> soft delete  (senior+ only)
 */

require_once __DIR__ . '/../config.php';

header('Content-Type: application/json');

$jwt     = require_auth();
$pdo     = db();
$staffId = (int) $jwt['staff_id'];
$homeId  = (int) $jwt['home_id'];
$repo    = new AuditedRepository($pdo, $staffId, $homeId, $_SERVER['REMOTE_ADDR'] ?? null);

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

    $sectionId = (int) ($_GET['section_id'] ?? 0);
    if ($sectionId > 0) {
        $stmt = $pdo->prepare(
            "SELECT * FROM care_interventions
             WHERE resident_id = ? AND section_id = ? AND status = 'active' AND deleted_at IS NULL
             ORDER BY id"
        );
        $stmt->execute([$residentId, $sectionId]);
    } else {
        $stmt = $pdo->prepare(
            "SELECT * FROM care_interventions
             WHERE resident_id = ? AND status = 'active' AND deleted_at IS NULL
             ORDER BY section_id, id"
        );
        $stmt->execute([$residentId]);
    }

    respond(['interventions' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(PDO $pdo, AuditedRepository $repo, int $staffId, int $homeId, array $jwt): never
{
    requireSenior($jwt);

    $in          = json_input();
    $residentId  = (int) ($in['resident_id'] ?? 0);
    $sectionId   = (int) ($in['section_id'] ?? 0);
    $description = trim((string) ($in['description'] ?? ''));

    $errors = [];
    if ($residentId <= 0)    $errors[] = 'resident_id is required';
    if ($sectionId <= 0)     $errors[] = 'section_id is required';
    if ($description === '') $errors[] = 'description is required';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, $homeId);
    requireOwnedSection($pdo, $sectionId, $homeId);

    $raId = isset($in['risk_assessment_id']) ? (int) $in['risk_assessment_id'] : null;

    $id = $repo->insert('care_interventions', [
        'home_id'            => $homeId,
        'resident_id'        => $residentId,
        'section_id'         => $sectionId,
        'risk_assessment_id' => $raId ?: null,
        'description'        => $description,
        'frequency'          => trim((string) ($in['frequency'] ?? '')) ?: null,
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
    requireOwnedIntervention($pdo, $id, $homeId);

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
        $allowed = ['active', 'completed', 'discontinued'];
        $status  = (string) $in['status'];
        if (!in_array($status, $allowed, true)) {
            respond(['error' => 'invalid status'], 422);
        }
        $data['status'] = $status;
    }
    if (array_key_exists('risk_assessment_id', $in)) {
        $data['risk_assessment_id'] = $in['risk_assessment_id'] ? (int) $in['risk_assessment_id'] : null;
    }

    if (empty($data)) {
        respond(['id' => $id]);
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

function requireOwnedSection(PDO $pdo, int $sectionId, int $homeId): void
{
    $stmt = $pdo->prepare(
        'SELECT 1 FROM care_plan_sections s
         JOIN residents r ON r.id = s.resident_id
         WHERE s.id = ? AND r.home_id = ? AND s.deleted_at IS NULL'
    );
    $stmt->execute([$sectionId, $homeId]);
    if (!$stmt->fetchColumn()) {
        respond(['error' => 'section not found in this home'], 404);
    }
}

function requireOwnedIntervention(PDO $pdo, int $interventionId, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT i.* FROM care_interventions i
         JOIN residents r ON r.id = i.resident_id
         WHERE i.id = ? AND r.home_id = ? AND i.deleted_at IS NULL'
    );
    $stmt->execute([$interventionId, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'intervention not found in this home'], 404);
    }
    return $row;
}
