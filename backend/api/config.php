<?php
// Care Package — shared DB config & helpers (PHP 8.3, PDO/MySQL).
declare(strict_types=1);

define('APP_ROOT', __DIR__);

// ---------------------------------------------------------------------
// Secrets are loaded from OUTSIDE the web root, never committed here.
// Create /home/seanstua/care_secrets.php (see care_secrets.php template).
// Override the path with the CARE_SECRETS env var if you keep it elsewhere.
// ---------------------------------------------------------------------
$secretsFile = getenv('CARE_SECRETS') ?: '/home2/seanstua/care_secrets.php';
$secrets = is_file($secretsFile) ? (require $secretsFile) : [];

const DB_HOST = 'localhost';
const DB_NAME = 'seanstua_care';
const DB_USER = 'seanstua_care';
define('DB_PASS',    $secrets['db_pass']    ?? '');
define('JWT_SECRET', $secrets['jwt_secret'] ?? '');
const JWT_TTL = 60 * 60 * 12; // 12 hours

// Fail loudly if the secrets file is missing/empty — better a clear error
// than silently running with no JWT secret.
if (DB_PASS === '' || JWT_SECRET === '') {
    http_response_code(500);
    echo json_encode(['message' => 'Server misconfigured: secrets unavailable']);
    exit;
}

// ---------------------------------------------------------------------
// Autoloader for classes in ./lib (AuditedRepository, RateLimiter, ...).
// Removes the need for explicit require_once in every endpoint.
// ---------------------------------------------------------------------
spl_autoload_register(static function (string $class): void {
    $file = __DIR__ . '/lib/' . $class . '.php';
    if (is_file($file)) {
        require_once $file;
    }
});

function db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(
            'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
            DB_USER, DB_PASS,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
        $pdo->exec("SET time_zone = '+00:00'");
    }
    return $pdo;
}

function json_input(): array {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw !== false ? $raw : '', true);
    return is_array($data) ? $data : [];
}

function respond($data, int $code = 200): never {
    http_response_code($code);
    header('Content-Type: application/json');
    echo json_encode($data);
    exit;
}

function fail(string $message, int $code = 400): never {
    respond(['message' => $message], $code);
}

// --- Minimal HS256 JWT (no Composer; mirrors the rest of the portfolio) ---
function b64url(string $s): string {
    return rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
}
function b64url_decode(string $s): string {
    return base64_decode(strtr($s, '-_', '+/'));
}

function jwt_encode(array $payload): string {
    $header = ['alg' => 'HS256', 'typ' => 'JWT'];
    $now = time();
    $payload['iat'] = $now;
    $payload['nbf'] = $now;
    $payload['exp'] = $now + JWT_TTL;
    $seg = [b64url(json_encode($header)), b64url(json_encode($payload))];
    $sig = hash_hmac('sha256', implode('.', $seg), JWT_SECRET, true);
    $seg[] = b64url($sig);
    return implode('.', $seg);
}

function jwt_decode(string $token): ?array {
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;
    [$h, $p, $s] = $parts;

    // Verify the signature (constant-time) before trusting anything.
    $expected = b64url(hash_hmac('sha256', "$h.$p", JWT_SECRET, true));
    if (!hash_equals($expected, $s)) return null;

    // Defence in depth: only accept HS256 / JWT headers.
    $header = json_decode(b64url_decode($h), true);
    if (!is_array($header) || ($header['alg'] ?? '') !== 'HS256' || ($header['typ'] ?? 'JWT') !== 'JWT') {
        return null;
    }

    $payload = json_decode(b64url_decode($p), true);
    if (!is_array($payload)) return null;

    $now = time();
    if (($payload['exp'] ?? 0) <= $now)      return null;  // expired
    if (($payload['nbf'] ?? 0) > $now + 60)  return null;  // not yet valid (60s skew)
    return $payload;
}

function require_auth(): array {
    $hdr = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/Bearer\s+(\S+)/', $hdr, $m)) fail('Missing token', 401);
    $payload = jwt_decode($m[1]);
    if ($payload === null) fail('Invalid or expired token', 401);

    // Re-validate against the DB so deactivation, role change or a forced
    // logout take effect immediately rather than after the 12-hour TTL.
    $staffId = (int) ($payload['sub'] ?? 0);
    $stmt = db()->prepare('SELECT active, role, token_version FROM staff WHERE id = ?');
    $stmt->execute([$staffId]);
    $staff = $stmt->fetch();

    if (!$staff || (int) $staff['active'] !== 1) {
        fail('Account is not active', 401);
    }
    if ((int) $staff['token_version'] !== (int) ($payload['tv'] ?? -1)) {
        fail('Session revoked, please sign in again', 401);
    }

    // Trust the DB for the live role; keep both naming conventions working.
    $payload['role']     = $staff['role'];
    $payload['staff_id'] = $staffId;
    $payload['home_id']  = (int) ($payload['home'] ?? 0);
    return $payload;
}

/** Force-logout a member of staff everywhere (deactivation, password change,
 *  lost device). Their existing tokens stop validating immediately. */
function revoke_staff_sessions(int $staffId): void {
    db()->prepare('UPDATE staff SET token_version = token_version + 1 WHERE id = ?')
        ->execute([$staffId]);
}

function requireSenior(array $jwt): void
{
    if (!in_array($jwt['role'] ?? '', ['seniorCarer', 'nurse', 'manager', 'admin'], true)) {
        fail('Senior role required for this action', 403);
    }
}

function audit(int $staffId, string $action, string $entity, ?int $entityId,
               ?string $detail = null, ?int $homeId = null): void {
    $stmt = db()->prepare(
        'INSERT INTO audit_log (staff_id, home_id, action, entity, entity_id, ip_address, detail)
         VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $staffId, $homeId, $action, $entity, $entityId,
        $_SERVER['REMOTE_ADDR'] ?? null, $detail,
    ]);
}
