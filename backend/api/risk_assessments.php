<?php
declare(strict_types=1);

/**
 * /api/risk_assessments.php — Smart Care
 *
 * GET    ?resident_id=1                         -> active assessments
 * GET    ?resident_id=1&type=waterlow&history=1 -> version history for a tool
 * POST   {resident_id, type, risk_level, ...}   -> record an assessment
 * PUT    ?id=5 {risk_level, total_score, ...}    -> re-assessment = supersede
 * DELETE ?id=5                                   -> soft delete
 */

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/lib/AuditedRepository.php';

header('Content-Type: application/json');

$jwt  = require_auth();
$pdo  = db();
$repo = new AuditedRepository(
    $pdo,
    (int) $jwt['sub'],
    (int) $jwt['home'],
    $_SERVER['REMOTE_ADDR'] ?? null
);

const RISK_TYPES  = [
    'falls', 'waterlow', 'purpose_t', 'must', 'moving_handling',
    'dols', 'choking', 'behaviour', 'other',
];
const RISK_LEVELS = ['low', 'medium', 'high', 'very_high'];

try {
    match ($_SERVER['REQUEST_METHOD']) {
        'GET'          => handleGet($pdo, $jwt),
        'POST'         => handleCreate($pdo, $repo, $jwt),
        'PUT', 'PATCH' => handleReview($pdo, $repo, $jwt),
        'DELETE'       => handleDelete($pdo, $repo, $jwt),
        default        => respond(['error' => 'Method not allowed'], 405),
    };
} catch (Throwable $e) {
    respond(['error' => 'Server error', 'detail' => $e->getMessage()], 500);
}

// =====================================================================
// Handlers
// =====================================================================

function handleGet(PDO $pdo, array $jwt): never
{
    $residentId = (int) ($_GET['resident_id'] ?? 0);
    if ($residentId <= 0) {
        respond(['error' => 'resident_id is required'], 422);
    }
    requireResidentInHome($pdo, $residentId, (int) $jwt['home']);

    if (!empty($_GET['history'])) {
        $type = (string) ($_GET['type'] ?? '');
        if (!in_array($type, RISK_TYPES, true)) {
            respond(['error' => 'valid type is required for history'], 422);
        }
        $stmt = $pdo->prepare(
            'SELECT * FROM risk_assessments
             WHERE resident_id = ? AND type = ? AND deleted_at IS NULL
             ORDER BY version_no DESC'
        );
        $stmt->execute([$residentId, $type]);
        respond(['history' => decodeDetail($stmt->fetchAll(PDO::FETCH_ASSOC))]);
    }

    $stmt = $pdo->prepare(
        "SELECT * FROM risk_assessments
         WHERE resident_id = ? AND status = 'active' AND deleted_at IS NULL
         ORDER BY type"
    );
    $stmt->execute([$residentId]);
    respond(['assessments' => decodeDetail($stmt->fetchAll(PDO::FETCH_ASSOC))]);
}

function handleCreate(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    $in         = json_input();
    $residentId = (int) ($in['resident_id'] ?? 0);
    $type       = (string) ($in['type'] ?? '');
    $riskLevel  = (string) ($in['risk_level'] ?? '');

    $errors = [];
    if ($residentId <= 0)                         $errors[] = 'resident_id is required';
    if (!in_array($type, RISK_TYPES, true))        $errors[] = 'invalid type';
    if (!in_array($riskLevel, RISK_LEVELS, true))  $errors[] = 'invalid risk_level';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, (int) $jwt['home']);

    $id = $repo->insert('risk_assessments', [
        'home_id'      => (int) $jwt['home'],
        'resident_id'  => $residentId,
        'type'         => $type,
        'tool_version' => trim((string) ($in['tool_version'] ?? '')) ?: null,
        'total_score'  => isset($in['total_score']) ? (int) $in['total_score'] : null,
        'risk_level'   => $riskLevel,
        'detail'       => encodeDetail($in['detail'] ?? null),
        'summary'      => trim((string) ($in['summary'] ?? '')) ?: null,
        'assessed_by'  => (int) $jwt['sub'],
        'review_due'   => $in['review_due'] ?? null,
        'version_no'   => 1,
        'status'       => 'active',
        'created_by'   => (int) $jwt['sub'],
    ], 'risk_assessment');

    respond(['id' => $id], 201);
}

function handleReview(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    $id = (int) ($_GET['id'] ?? 0);
    $in = json_input();
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    $old = requireOwnedAssessment($pdo, $id, (int) $jwt['home']);
    if ($old['status'] !== 'active') {
        respond(['error' => 'only the active version can be re-assessed'], 409);
    }

    $riskLevel = (string) ($in['risk_level'] ?? $old['risk_level']);
    if (!in_array($riskLevel, RISK_LEVELS, true)) {
        respond(['error' => 'invalid risk_level'], 422);
    }

    $newId = $repo->supersede(
        'risk_assessments',
        'risk_assessment',
        $id,
        [
            'home_id'      => (int) $old['home_id'],
            'resident_id'  => (int) $old['resident_id'],
            'type'         => $old['type'],
            'tool_version' => $in['tool_version'] ?? $old['tool_version'],
            'total_score'  => array_key_exists('total_score', $in)
                                ? (int) $in['total_score']
                                : (isset($old['total_score']) ? (int) $old['total_score'] : null),
            'risk_level'   => $riskLevel,
            'detail'       => array_key_exists('detail', $in)
                                ? encodeDetail($in['detail'])
                                : $old['detail'],
            'summary'      => $in['summary'] ?? $old['summary'],
            'assessed_by'  => (int) $jwt['sub'],
            'review_due'   => $in['review_due'] ?? null,
            'created_by'   => (int) $jwt['sub'],
        ]
    );

    respond(['id' => $newId, 'superseded' => $id]);
}

function handleDelete(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedAssessment($pdo, $id, (int) $jwt['home']);
    $repo->softDelete('risk_assessments', $id, 'risk_assessment');
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

function requireOwnedAssessment(PDO $pdo, int $assessmentId, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT a.* FROM risk_assessments a
         JOIN residents r ON r.id = a.resident_id
         WHERE a.id = ? AND r.home_id = ? AND a.deleted_at IS NULL'
    );
    $stmt->execute([$assessmentId, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'assessment not found in this home'], 404);
    }
    return $row;
}

function encodeDetail(mixed $detail): ?string
{
    if ($detail === null || $detail === '') {
        return null;
    }
    if (is_array($detail)) {
        return json_encode($detail, JSON_UNESCAPED_UNICODE);
    }
    return (string) $detail;
}

function decodeDetail(array $rows): array
{
    foreach ($rows as &$row) {
        if (isset($row['detail']) && is_string($row['detail'])) {
            $decoded = json_decode($row['detail'], true);
            $row['detail'] = is_array($decoded) ? $decoded : null;
        }
    }
    return $rows;
}
