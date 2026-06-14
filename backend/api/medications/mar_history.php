<?php
// GET /medications/mar_history.php?resident_id=5&from=2026-06-01T00:00:00&to=2026-06-10T23:59:59
require __DIR__ . '/../config.php';
$auth = require_auth();
$homeId = (int)$auth['home'];

$residentId = (int)($_GET['resident_id'] ?? 0);
if ($residentId === 0) fail('resident_id is required');

$from = $_GET['from'] ?? date('Y-m-d', strtotime('-7 days')) . ' 00:00:00';
$to   = $_GET['to']   ?? date('Y-m-d 23:59:59');

// Verify resident belongs to this home.
$own = db()->prepare('SELECT id FROM residents WHERE id = ? AND home_id = ?');
$own->execute([$residentId, $homeId]);
if (!$own->fetch()) fail('Resident not found', 404);

$stmt = db()->prepare(
    "SELECT e.*,
            m.name AS medication_name, m.dose, m.controlled_drug,
            s.name AS administered_by_name
     FROM mar_entries e
     JOIN medications m ON m.id = e.medication_id
     LEFT JOIN staff s ON s.id = e.administered_by
     WHERE e.resident_id = ? AND e.scheduled_for BETWEEN ? AND ?
     ORDER BY e.scheduled_for DESC
     LIMIT 200"
);
$stmt->execute([$residentId, $from, $to]);
respond(['entries' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
