<?php
// Care Package — shared DB config & helpers (PHP 8.3, PDO/MySQL).
declare(strict_types=1);

define('APP_ROOT', __DIR__);

const DB_HOST = 'localhost';
const DB_NAME = 'seanstua_care';
const DB_USER = 'seanstua_care';
const DB_PASS = '@letmein123321SS';
const JWT_SECRET = 'c9e4a7d1f6b3c8e2a5d0f7b4c1e9a6d3b8f5c2a7e0d4f1b6c9a3e8d5f2b7c4a1';
const JWT_TTL = 60 * 60 * 12; // 12 hours

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
    $data = json_decode($raw, true);
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
    $payload['iat'] = time();
    $payload['exp'] = time() + JWT_TTL;
    $seg = [b64url(json_encode($header)), b64url(json_encode($payload))];
    $sig = hash_hmac('sha256', implode('.', $seg), JWT_SECRET, true);
    $seg[] = b64url($sig);
    return implode('.', $seg);
}

function jwt_decode(string $token): ?array {
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;
    [$h, $p, $s] = $parts;
    $check = b64url(hash_hmac('sha256', "$h.$p", JWT_SECRET, true));
    if (!hash_equals($check, $s)) return null;
    $payload = json_decode(b64url_decode($p), true);
    if (!is_array($payload) || ($payload['exp'] ?? 0) < time()) return null;
    return $payload;
}

function require_auth(): array {
    $hdr = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/Bearer\s+(.+)/', $hdr, $m)) fail('Missing token', 401);
    $payload = jwt_decode($m[1]);
    if ($payload === null) fail('Invalid or expired token', 401);
    return $payload;
}

function audit(int $staffId, string $action, string $entity, ?int $entityId, ?string $detail = null): void {
    $stmt = db()->prepare(
        'INSERT INTO audit_log (staff_id, action, entity, entity_id, ip_address, detail)
         VALUES (?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $staffId, $action, $entity, $entityId,
        $_SERVER['REMOTE_ADDR'] ?? null, $detail,
    ]);
}
