<?php
// GET /handover/list.php?limit=20
require __DIR__ . '/../../config.php';
$auth = require_auth();
$limit = max(1, min(100, (int)($_GET['limit'] ?? 20)));

$stmt = db()->prepare(
    'SELECT h.id, h.home_id, h.staff_id, h.shift, h.content, h.created_at,
            s.name AS staff_name
       FROM handover_notes h
       LEFT JOIN staff s ON s.id = h.staff_id
      WHERE h.home_id = ?
      ORDER BY h.created_at DESC
      LIMIT ?'
);
$stmt->execute([(int)$auth['home'], $limit]);
respond(['notes' => $stmt->fetchAll()]);
