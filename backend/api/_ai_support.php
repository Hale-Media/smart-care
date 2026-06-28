<?php
// =============================================================================
//  Smart Care · AI layer · shared support
// -----------------------------------------------------------------------------
//  Self-contained helpers in your house style (PDO, array(), isset() ternaries,
//  hand-rolled HS256 JWT with token_version revocation).
//
//  YOU ALREADY HAVE EQUIVALENTS. If your real auth/audit helpers differ in name
//  or signature, delete the matching function here and call yours instead — the
//  endpoints only depend on the three functions:
//      ai_require_auth($pdo)   -> array staff context (id, home_id, role, ...)
//      ai_audit($pdo, ...)     -> writes one audit_log row
//      ai_resolve_home_id(...) -> int|null owning home for an (entity,id)
//
//  Assumptions to confirm (all isolated to this file):
//    * JWT claims: sub = staff id, home_id = active home, tv = token_version.
//    * Your JWT secret is reachable as a constant. Point SMARTCARE_JWT_SECRET
//      at your existing config rather than hardcoding it.
// =============================================================================

// --- wire to your existing bootstrap --------------------------------------
// require_once __DIR__ . '/../config.php';   // your $pdo / secret live here
// define('SMARTCARE_JWT_SECRET', $YOUR_EXISTING_SECRET);

if (!defined('SMARTCARE_JWT_SECRET')) {
    // Bridge to the project's JWT_SECRET constant when config.php is already loaded.
    define('SMARTCARE_JWT_SECRET', defined('JWT_SECRET') ? JWT_SECRET : (getenv('SMARTCARE_JWT_SECRET') ?: ''));
}

// Entities the AI layer is allowed to annotate, mapped to the SQL that returns
// the owning home_id. care_calls / incidents carry no home_id of their own, so
// we resolve through residents. This list IS the allow-list.
function ai_entity_home_sql($entity)
{
    $map = array(
        'handover_note' => 'SELECT home_id AS home_id FROM handover_notes WHERE id = ? LIMIT 1',
        'care_call'     => 'SELECT r.home_id AS home_id FROM care_calls c '
                         . 'JOIN residents r ON r.id = c.resident_id WHERE c.id = ? LIMIT 1',
        'incident'      => 'SELECT r.home_id AS home_id FROM incidents i '
                         . 'JOIN residents r ON r.id = i.resident_id WHERE i.id = ? LIMIT 1',
    );
    return isset($map[$entity]) ? $map[$entity] : null;
}

function ai_json($status, $data)
{
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($data);
    exit;
}

function ai_b64url_decode($s)
{
    $pad = strlen($s) % 4;
    if ($pad) { $s .= str_repeat('=', 4 - $pad); }
    return base64_decode(strtr($s, '-_', '+/'));
}

function ai_b64url_encode($bin)
{
    return rtrim(strtr(base64_encode($bin), '+/', '-_'), '=');
}

// Verify an HS256 JWT and return its claims, or false.
function ai_jwt_verify($jwt)
{
    $parts = explode('.', $jwt);
    if (count($parts) !== 3) { return false; }
    list($h64, $p64, $s64) = $parts;
    $expected = ai_b64url_encode(
        hash_hmac('sha256', $h64 . '.' . $p64, SMARTCARE_JWT_SECRET, true)
    );
    if (!hash_equals($expected, $s64)) { return false; }
    $payload = json_decode(ai_b64url_decode($p64), true);
    if (!is_array($payload)) { return false; }
    if (isset($payload['exp']) && time() >= (int)$payload['exp']) { return false; }
    return $payload;
}

// Read the bearer token, verify it, enforce token_version revocation, and
// return the live staff context. Halts with 401 on any failure.
function ai_require_auth($pdo)
{
    $hdr = isset($_SERVER['HTTP_AUTHORIZATION']) ? $_SERVER['HTTP_AUTHORIZATION'] : '';
    if ($hdr === '' && function_exists('apache_request_headers')) {
        $h = apache_request_headers();
        $hdr = isset($h['Authorization']) ? $h['Authorization'] : '';
    }
    if (stripos($hdr, 'Bearer ') !== 0) {
        ai_json(401, array('error' => 'missing_token'));
    }
    $claims = ai_jwt_verify(trim(substr($hdr, 7)));
    if ($claims === false) {
        ai_json(401, array('error' => 'invalid_token'));
    }

    $staffId = isset($claims['sub']) ? (int)$claims['sub'] : 0;
    $tv      = isset($claims['tv']) ? (int)$claims['tv'] : -1;

    $stmt = $pdo->prepare(
        'SELECT id, company_id, home_id, role, can_switch_homes, token_version, active '
        . 'FROM staff WHERE id = ? LIMIT 1'
    );
    $stmt->execute(array($staffId));
    $staff = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$staff || (int)$staff['active'] !== 1) {
        ai_json(401, array('error' => 'inactive_account'));
    }
    if ((int)$staff['token_version'] !== $tv) {
        ai_json(401, array('error' => 'token_revoked'));
    }

    // Active home comes from the token (set by your home-switch flow), not the
    // staff row, so home-switching is respected. Falls back to the home row.
    // JWT encodes the active home under 'home' (see config.php jwt_encode); fall back to DB row.
    $activeHome = isset($claims['home']) ? (int)$claims['home'] : (int)$staff['home_id'];
    $staff['active_home_id'] = $activeHome;
    return $staff;
}

// True if the staff role is at or above senior (the review-queue audience).
function ai_is_senior($staff)
{
    $role = isset($staff['role']) ? $staff['role'] : '';
    return in_array($role, array('seniorCarer', 'nurse', 'manager', 'admin'), true);
}

// Resolve the owning home for an (entity, entity_id) from the DB. Returns null
// if the entity is unknown or the row does not exist.
function ai_resolve_home_id($pdo, $entity, $entityId)
{
    $sql = ai_entity_home_sql($entity);
    if ($sql === null) { return null; }
    $stmt = $pdo->prepare($sql);
    $stmt->execute(array((int)$entityId));
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return $row ? (int)$row['home_id'] : null;
}

// Insert one audit_log row, matching your existing column layout exactly.
function ai_audit($pdo, $staffId, $homeId, $action, $entity, $entityId, $detail, $before, $after)
{
    $stmt = $pdo->prepare(
        'INSERT INTO audit_log '
        . '(staff_id, home_id, action, entity, entity_id, ip_address, detail, before_json, after_json, created_at) '
        . 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())'
    );
    $stmt->execute(array(
        $staffId !== null ? (int)$staffId : null,
        $homeId !== null ? (int)$homeId : null,
        $action,
        $entity,
        $entityId !== null ? (int)$entityId : null,
        isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : null,
        $detail,
        $before !== null ? json_encode($before) : null,
        $after !== null ? json_encode($after) : null,
    ));
}

// Read + decode a JSON request body into an array.
function ai_read_json_body()
{
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    return is_array($data) ? $data : array();
}
