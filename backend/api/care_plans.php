<?php
declare(strict_types=1);

/**
 * /api/care_plans.php — Smart Care
 *
 * GET    ?resident_id=1                       -> active care plan sections
 * GET    ?resident_id=1&domain=skin&history=1 -> version history for a domain
 * POST   {resident_id, domain, title, ...}    -> create a section
 * PUT    ?id=5 {how_to_support_me, ...}        -> review = supersede (new version)
 * DELETE ?id=5                                 -> soft delete
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

const PLAN_DOMAINS = [
    'mobility', 'nutrition', 'hydration', 'skin', 'continence', 'communication',
    'mental_health', 'social', 'personal_care', 'medication', 'end_of_life', 'other',
];

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
        $domain = (string) ($_GET['domain'] ?? '');
        if (!in_array($domain, PLAN_DOMAINS, true)) {
            respond(['error' => 'valid domain is required for history'], 422);
        }
        $stmt = $pdo->prepare(
            'SELECT * FROM care_plan_sections
             WHERE resident_id = ? AND domain = ? AND deleted_at IS NULL
             ORDER BY version_no DESC'
        );
        $stmt->execute([$residentId, $domain]);
        respond(['history' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    $stmt = $pdo->prepare(
        "SELECT * FROM care_plan_sections
         WHERE resident_id = ? AND status = 'active' AND deleted_at IS NULL
         ORDER BY domain"
    );
    $stmt->execute([$residentId]);
    respond(['sections' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function handleCreate(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    $in         = json_input();
    $residentId = (int) ($in['resident_id'] ?? 0);
    $domain     = (string) ($in['domain'] ?? '');
    $title      = trim((string) ($in['title'] ?? ''));
    $support    = trim((string) ($in['how_to_support_me'] ?? ''));

    $errors = [];
    if ($residentId <= 0)                        $errors[] = 'resident_id is required';
    if (!in_array($domain, PLAN_DOMAINS, true))  $errors[] = 'invalid domain';
    if ($title === '')                           $errors[] = 'title is required';
    if ($support === '')                         $errors[] = 'how_to_support_me is required';
    if ($errors) {
        respond(['errors' => $errors], 422);
    }
    requireResidentInHome($pdo, $residentId, (int) $jwt['home']);

    $id = $repo->insert('care_plan_sections', [
        'home_id'            => (int) $jwt['home'],
        'resident_id'        => $residentId,
        'domain'             => $domain,
        'title'              => $title,
        'what_matters_to_me' => trim((string) ($in['what_matters_to_me'] ?? '')) ?: null,
        'how_to_support_me'  => $support,
        'goals'              => trim((string) ($in['goals'] ?? '')) ?: null,
        'agreed_with'        => trim((string) ($in['agreed_with'] ?? '')) ?: null,
        'review_due'         => $in['review_due'] ?? null,
        'version_no'         => 1,
        'status'             => 'active',
        'row_version'        => 1,
        'created_by'         => (int) $jwt['sub'],
    ], 'care_plan_section');

    respond(['id' => $id], 201);
}

function handleReview(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    $id = (int) ($_GET['id'] ?? 0);
    $in = json_input();
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    $old = requireOwnedSection($pdo, $id, (int) $jwt['home']);
    if ($old['status'] !== 'active') {
        respond(['error' => 'only the active version can be reviewed'], 409);
    }

    $support = trim((string) ($in['how_to_support_me'] ?? $old['how_to_support_me']));
    if ($support === '') {
        respond(['error' => 'how_to_support_me cannot be empty'], 422);
    }

    $newId = $repo->supersede(
        'care_plan_sections',
        'care_plan_section',
        $id,
        [
            'home_id'            => (int) $old['home_id'],
            'resident_id'        => (int) $old['resident_id'],
            'domain'             => $old['domain'],
            'title'              => trim((string) ($in['title'] ?? $old['title'])),
            'what_matters_to_me' => array_key_exists('what_matters_to_me', $in)
                                      ? (trim((string) $in['what_matters_to_me']) ?: null)
                                      : $old['what_matters_to_me'],
            'how_to_support_me'  => $support,
            'goals'              => array_key_exists('goals', $in)
                                      ? (trim((string) $in['goals']) ?: null)
                                      : $old['goals'],
            'agreed_with'        => $in['agreed_with'] ?? $old['agreed_with'],
            'review_due'         => $in['review_due'] ?? null,
            'created_by'         => (int) $jwt['sub'],
        ],
        ['effective_to' => $repo->nowPublic()]
    );

    respond(['id' => $newId, 'superseded' => $id]);
}

function handleDelete(PDO $pdo, AuditedRepository $repo, array $jwt): never
{
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        respond(['error' => 'id is required'], 422);
    }
    requireOwnedSection($pdo, $id, (int) $jwt['home']);
    $repo->softDelete('care_plan_sections', $id, 'care_plan_section');
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

function requireOwnedSection(PDO $pdo, int $sectionId, int $homeId): array
{
    $stmt = $pdo->prepare(
        'SELECT s.* FROM care_plan_sections s
         JOIN residents r ON r.id = s.resident_id
         WHERE s.id = ? AND r.home_id = ? AND s.deleted_at IS NULL'
    );
    $stmt->execute([$sectionId, $homeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond(['error' => 'section not found in this home'], 404);
    }
    return $row;
}
