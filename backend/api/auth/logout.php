<?php
// POST /auth/logout.php — revoke all sessions for the signed-in staff member.
// Increments token_version so every existing token (other devices, browsers)
// stops validating immediately.
require __DIR__ . '/../config.php';
$jwt = require_auth();
revoke_staff_sessions((int) $jwt['staff_id']);
respond(['ok' => true]);
