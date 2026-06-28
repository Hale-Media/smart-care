<?php
// =============================================================================
//  GET  ai_flags_list.php
//  The senior's review queue. Returns AI annotations for the caller's active
//  home, newest first. Tenant-scoped and senior-gated.
// -----------------------------------------------------------------------------
//  Query:
//    state   pending | confirmed | dismissed   (default: pending)
//    entity  optional filter (care_call | handover_note | incident)
//    limit   1..100 (default 50)
// =============================================================================

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/_ai_support.php';
$pdo = db();

$method = isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : 'GET';
if ($method !== 'GET') {
    ai_json(405, array('error' => 'method_not_allowed'));
}

$staff = ai_require_auth($pdo);
if (!ai_is_senior($staff)) {
    ai_json(403, array('error' => 'insufficient_role'));
}

$state = isset($_GET['state']) ? (string)$_GET['state'] : 'pending';
if (!in_array($state, array('pending', 'confirmed', 'dismissed'), true)) {
    ai_json(422, array('error' => 'bad_state'));
}

$entity = isset($_GET['entity']) ? (string)$_GET['entity'] : '';
$limit  = isset($_GET['limit']) ? (int)$_GET['limit'] : 50;
if ($limit < 1) { $limit = 1; }
if ($limit > 100) { $limit = 100; }

// Always constrained to the caller's active home — the tenant boundary.
$where  = array('home_id = ?', 'review_state = ?');
$params = array((int)$staff['active_home_id'], $state);

if ($entity !== '') {
    if (ai_entity_home_sql($entity) === null) {
        ai_json(422, array('error' => 'unsupported_entity'));
    }
    $where[]  = 'entity = ?';
    $params[] = $entity;
}

$sql = 'SELECT id, entity, entity_id, ai_summary, ai_risk_flags, ai_mood, ai_follow_up, '
     . '       model_name, model_sha256, review_state, reviewed_by, reviewed_at, created_at '
     . 'FROM ai_annotations WHERE ' . implode(' AND ', $where) . ' '
     . 'ORDER BY ai_follow_up DESC, created_at DESC '
     . 'LIMIT ' . $limit;

$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

$items = array();
foreach ($rows as $r) {
    $flags = json_decode(isset($r['ai_risk_flags']) ? $r['ai_risk_flags'] : '[]', true);
    $items[] = array(
        'id'           => (int)$r['id'],
        'entity'       => $r['entity'],
        'entity_id'    => (int)$r['entity_id'],
        'summary'      => $r['ai_summary'],
        'risk_flags'   => is_array($flags) ? $flags : array(),
        'mood'         => $r['ai_mood'],
        'follow_up'    => (int)$r['ai_follow_up'] === 1,
        'model_name'   => $r['model_name'],
        'model_sha256' => $r['model_sha256'],
        'review_state' => $r['review_state'],
        'reviewed_by'  => isset($r['reviewed_by']) ? (int)$r['reviewed_by'] : null,
        'reviewed_at'  => $r['reviewed_at'],
        'created_at'   => $r['created_at'],
    );
}

ai_json(200, array('ok' => true, 'count' => count($items), 'items' => $items));
