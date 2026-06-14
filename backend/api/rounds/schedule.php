<?php
// POST /rounds/schedule.php — creates a batch of round slots for one resident.
// Body: { resident_id, type, interval_hours, start_at, count }
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();

$residentId    = (int)($in['resident_id'] ?? 0);
$type          = $in['type'] ?? 'welfare';
$intervalHours = max(1, (int)($in['interval_hours'] ?? 2));
$startAt       = $in['start_at'] ?? date('Y-m-d H:i:s');
$count         = min(24, max(1, (int)($in['count'] ?? 4)));

if ($residentId === 0) fail('resident_id is required');

// Verify resident belongs to this home
$check = db()->prepare("SELECT id FROM residents WHERE id = ? AND home_id = ?");
$check->execute([$residentId, (int)$auth['home']]);
if (!$check->fetch()) fail('Resident not found', 404);

$due     = new DateTime($startAt);
$created = [];
$stmt    = db()->prepare(
    'INSERT INTO care_rounds (resident_id, due_at, type) VALUES (?,?,?)'
);
for ($i = 0; $i < $count; $i++) {
    $stmt->execute([$residentId, $due->format('Y-m-d H:i:s'), $type]);
    $created[] = ['id' => (int)db()->lastInsertId(), 'due_at' => $due->format('Y-m-d H:i:s')];
    $due->modify("+{$intervalHours} hours");
}
audit((int)$auth['sub'], 'schedule', 'round', $residentId, "{$count}×{$type}");
respond(['rounds' => $created], 201);
