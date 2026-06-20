<?php
declare(strict_types=1);

/**
 * RateLimiter — Smart Care
 *
 * Simple, DB-backed sliding-window limiter for shared hosting (no Redis).
 * Use one instance per "scope" (e.g. 'login', 'witness_pin'); the
 * identifier is whatever you're protecting against (a staff id, an email,
 * an IP). Counts failures within a window; locks out once the threshold
 * is hit; a success clears the record.
 *
 *   $rl  = new RateLimiter($pdo, 'witness_pin', maxAttempts: 5, windowSeconds: 900, lockoutSeconds: 900);
 *   $key = "home:{$homeId}:witness:{$witnessId}";
 *
 *   if (($wait = $rl->lockedFor($key)) !== null) {
 *       respond(429, ['error' => 'too many attempts', 'retry_after' => $wait]);
 *   }
 *   if (!$pinOk) { $rl->recordFailure($key); respond(401, ['error' => 'incorrect']); }
 *   $rl->recordSuccess($key);
 */
final class RateLimiter
{
    public function __construct(
        private PDO $pdo,
        private string $scope,
        private int $maxAttempts   = 5,
        private int $windowSeconds = 900,   // 15 min window
        private int $lockoutSeconds = 900,  // 15 min lockout
    ) {}

    /** Seconds remaining on a lockout, or null if not locked. */
    public function lockedFor(string $identifier): ?int
    {
        $row = $this->row($identifier);
        if ($row === null || $row['locked_until'] === null) {
            return null;
        }
        $remaining = $this->ts($row['locked_until']) - time();
        return $remaining > 0 ? $remaining : null;
    }

    /** Record a failed attempt; lock out once the threshold is reached. */
    public function recordFailure(string $identifier): void
    {
        $now = time();
        $row = $this->row($identifier);

        // No row, or the window has expired -> start a fresh window.
        if ($row === null || ($now - $this->ts($row['window_started_at'])) > $this->windowSeconds) {
            $this->upsert($identifier, 1, $now, null);
            return;
        }

        $attempts    = (int) $row['attempts'] + 1;
        $lockedUntil = $attempts >= $this->maxAttempts ? $now + $this->lockoutSeconds : null;
        $this->upsert($identifier, $attempts, $this->ts($row['window_started_at']), $lockedUntil);
    }

    /** Clear the record after a successful attempt. */
    public function recordSuccess(string $identifier): void
    {
        $stmt = $this->pdo->prepare('DELETE FROM auth_throttle WHERE scope = ? AND identifier = ?');
        $stmt->execute([$this->scope, $identifier]);
    }

    /** Attempts left before lockout (informational). */
    public function remaining(string $identifier): int
    {
        $row = $this->row($identifier);
        if ($row === null || (time() - $this->ts($row['window_started_at'])) > $this->windowSeconds) {
            return $this->maxAttempts;
        }
        return max(0, $this->maxAttempts - (int) $row['attempts']);
    }

    // ---- internals (UTC throughout, consistent with the endpoints) ----

    private function row(string $identifier): ?array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM auth_throttle WHERE scope = ? AND identifier = ?');
        $stmt->execute([$this->scope, $identifier]);
        $r = $stmt->fetch(PDO::FETCH_ASSOC);
        return $r === false ? null : $r;
    }

    private function upsert(string $identifier, int $attempts, int $windowStart, ?int $lockedUntil): void
    {
        $stmt = $this->pdo->prepare(
            'INSERT INTO auth_throttle
                 (scope, identifier, attempts, window_started_at, locked_until, updated_at)
             VALUES (?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                 attempts          = VALUES(attempts),
                 window_started_at = VALUES(window_started_at),
                 locked_until      = VALUES(locked_until),
                 updated_at        = VALUES(updated_at)'
        );
        $stmt->execute([
            $this->scope,
            $identifier,
            $attempts,
            gmdate('Y-m-d H:i:s', $windowStart),
            $lockedUntil === null ? null : gmdate('Y-m-d H:i:s', $lockedUntil),
            gmdate('Y-m-d H:i:s'),
        ]);
    }

    private function ts(string $utcDatetime): int
    {
        return (new DateTimeImmutable($utcDatetime, new DateTimeZone('UTC')))->getTimestamp();
    }
}
