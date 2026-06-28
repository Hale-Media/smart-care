<?php
// =============================================================================
//  PUT/POST  ai_annotation_upsert.php
//  Write (or update) the on-device AI annotation for one note entity.
//  Called by the carer's app right after a note saves; the inference already
//  ran on-device, so this only stores the derived JSON.
// -----------------------------------------------------------------------------
//  Body (JSON):
//    entity        "care_call" | "handover_note" | "incident"   (required)
//    entity_id     int                                          (required)
//    ai_summary    string
//    ai_risk_flags array of strings
//    ai_mood       string
//    ai_follow_up  bool
//    model_name    string
//    model_sha256  64-char hex
// =============================================================================

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/_ai_support.php';
$pdo = db();

$method = isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : 'GET';
if ($method !== 'PUT' && $method !== 'POST') {
    ai_json(405, array('error' => 'method_not_allowed'));
}

$staff = ai_require_auth($pdo);
$body  = ai_read_json_body();

$entity   = isset($body['entity']) ? (string)$body['entity'] : '';
$entityId = isset($body['entity_id']) ? (int)$body['entity_id'] : 0;

if ($entity === '' || $entityId <= 0) {
    ai_json(422, array('error' => 'entity_and_id_required'));
}
if (ai_entity_home_sql($entity) === null) {
    ai_json(422, array('error' => 'unsupported_entity'));
}

// --- TENANT ISOLATION GATE -------------------------------------------------
// Resolve the entity's TRUE owning home from the DB. Never trust a home_id
// from the client. If it doesn't resolve, or belongs to another home, reject.
$ownerHome = ai_resolve_home_id($pdo, $entity, $entityId);
if ($ownerHome === null) {
    ai_json(404, array('error' => 'entity_not_found'));
}
if ($ownerHome !== (int)$staff['active_home_id']) {
    ai_audit(
        $pdo, $staff['id'], $staff['active_home_id'], 'ai_annotation_denied',
        $entity, $entityId, 'cross-home write blocked', null, null
    );
    ai_json(403, array('error' => 'wrong_home'));
}

// --- normalise inputs ------------------------------------------------------
$summary  = isset($body['ai_summary']) ? trim((string)$body['ai_summary']) : null;
$mood     = isset($body['ai_mood']) ? trim((string)$body['ai_mood']) : null;
$followUp = (isset($body['ai_follow_up']) && $body['ai_follow_up']) ? 1 : 0;
$model    = isset($body['model_name']) ? trim((string)$body['model_name']) : null;
$sha      = isset($body['model_sha256']) ? trim((string)$body['model_sha256']) : null;

$flags = array();
if (isset($body['ai_risk_flags']) && is_array($body['ai_risk_flags'])) {
    foreach ($body['ai_risk_flags'] as $f) {
        $f = trim((string)$f);
        if ($f !== '') { $flags[] = mb_substr($f, 0, 120); }
    }
}
$flagsJson = json_encode($flags);

// basic provenance hygiene: sha must look like a sha-256 if present
if ($sha !== null && $sha !== '' && !preg_match('/^[a-f0-9]{64}$/i', $sha)) {
    $sha = null;
}

// --- upsert (one annotation per entity, enforced by uq_entity) -------------
$sql = 'INSERT INTO ai_annotations '
     . '(home_id, entity, entity_id, ai_summary, ai_risk_flags, ai_mood, ai_follow_up, '
     . ' model_name, model_sha256, review_state, created_at, updated_at) '
     . "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', NOW(), NOW()) "
     . 'ON DUPLICATE KEY UPDATE '
     . '  ai_summary = VALUES(ai_summary), '
     . '  ai_risk_flags = VALUES(ai_risk_flags), '
     . '  ai_mood = VALUES(ai_mood), '
     . '  ai_follow_up = VALUES(ai_follow_up), '
     . '  model_name = VALUES(model_name), '
     . '  model_sha256 = VALUES(model_sha256), '
     // re-running inference resets review to pending: the human reviews the
     // latest analysis, never a stale confirmation.
     . "  review_state = 'pending', "
     . '  reviewed_by = NULL, '
     . '  reviewed_at = NULL, '
     . '  updated_at = NOW()';

$stmt = $pdo->prepare($sql);
$stmt->execute(array(
    $ownerHome, $entity, $entityId, $summary, $flagsJson, $mood, $followUp, $model, $sha,
));

$annotationId = (int)$pdo->lastInsertId();
// On an UPDATE, lastInsertId() is 0; fetch the id for the response.
if ($annotationId === 0) {
    $look = $pdo->prepare('SELECT id FROM ai_annotations WHERE entity = ? AND entity_id = ? LIMIT 1');
    $look->execute(array($entity, $entityId));
    $annotationId = (int)$look->fetchColumn();
}

ai_audit(
    $pdo, $staff['id'], $ownerHome, 'ai_annotation_upsert', $entity, $entityId,
    'flags=' . count($flags) . ' followUp=' . $followUp . ' model=' . ($model ?: '?'),
    null,
    array('summary' => $summary, 'flags' => $flags, 'mood' => $mood, 'sha' => $sha)
);

ai_json(200, array(
    'ok' => true,
    'id' => $annotationId,
    'review_state' => 'pending',
));
