<?php
// GET /medications/list.php?resident_id=5
require __DIR__ . '/../config.php';
$auth = require_auth();
$homeId = (int)$auth['home'];

$residentId = (int)($_GET['resident_id'] ?? 0);
if ($residentId === 0) fail('resident_id is required');

// Verify resident belongs to this home.
$own = db()->prepare('SELECT id FROM residents WHERE id = ? AND home_id = ?');
$own->execute([$residentId, $homeId]);
if (!$own->fetch()) fail('Resident not found', 404);

$stmt = db()->prepare(
    "SELECT m.*,
            e.administered_at  AS last_administered_at,
            s.name             AS last_administered_by_name
     FROM medications m
     LEFT JOIN mar_entries e ON e.id = (
         SELECT id FROM mar_entries
         WHERE medication_id = m.id
         ORDER BY administered_at DESC
         LIMIT 1
     )
     LEFT JOIN staff s ON s.id = e.administered_by
     WHERE m.resident_id = ? AND m.active = 1
     ORDER BY m.name"
);
$stmt->execute([$residentId]);
respond(['medications' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
