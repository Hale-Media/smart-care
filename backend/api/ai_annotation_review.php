<?php
// =============================================================================
//  POST  ai_annotation_review.php
//  A senior confirms or dismisses an AI annotation. Records who/when, writes an
//  audit entry. This is the human-in-the-loop step that makes the AI layer
//  decision-SUPPORT rather than decision-making.
// -----------------------------------------------------------------------------
//  Body (JSON):
//    id        int annotation id   (required)
//    decision  "confirmed" | "dismissed"   (required)
//    note      optional reviewer note (stored only in the audit detail)
// =============================================================================

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/_ai_support.php';
$pdo = db();

$method = isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : 'GET';
if ($method !== 'POST') {
    ai_json(405, array('error' => 'method_not_allowed'));
}

$staff = ai_require_auth($pdo);
if (!ai_is_senior($staff)) {
    ai_json(403, array('error' => 'insufficient_role'));
}

$body     = ai_read_json_body();
$id       = isset($body['id']) ? (int)$body['id'] : 0;
$decision = isset($body['decision']) ? (string)$body['decision'] : '';
$note     = isset($body['note']) ? trim((string)$body['note']) : '';

if ($id <= 0 || !in_array($decision, array('confirmed', 'dismissed'), true)) {
    ai_json(422, array('error' => 'id_and_decision_required'));
}

// Load the annotation and enforce the tenant boundary before mutating.
$stmt = $pdo->prepare(
    'SELECT id, home_id, entity, entity_id, review_state FROM ai_annotations WHERE id = ? LIMIT 1'
);
$stmt->execute(array($id));
$ann = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$ann) {
    ai_json(404, array('error' => 'not_found'));
}
if ((int)$ann['home_id'] !== (int)$staff['active_home_id']) {
    ai_audit(
        $pdo, $staff['id'], $staff['active_home_id'], 'ai_review_denied',
        $ann['entity'], (int)$ann['entity_id'], 'cross-home review blocked', null, null
    );
    ai_json(403, array('error' => 'wrong_home'));
}

$before = array('review_state' => $ann['review_state']);

$upd = $pdo->prepare(
    'UPDATE ai_annotations SET review_state = ?, reviewed_by = ?, reviewed_at = NOW(), updated_at = NOW() '
    . 'WHERE id = ? LIMIT 1'
);
$upd->execute(array($decision, (int)$staff['id'], $id));

ai_audit(
    $pdo, $staff['id'], (int)$ann['home_id'], 'ai_annotation_review',
    $ann['entity'], (int)$ann['entity_id'],
    'decision=' . $decision . ($note !== '' ? (' note=' . mb_substr($note, 0, 200)) : ''),
    $before,
    array('review_state' => $decision, 'reviewed_by' => (int)$staff['id'])
);

ai_json(200, array('ok' => true, 'id' => $id, 'review_state' => $decision));
