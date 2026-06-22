<?php
// POST /handover/create.php
require __DIR__ . '/../config.php';
$auth = require_auth();
$in = json_input();

if (trim($in['content'] ?? '') === '') fail('content is required');
$shift = $in['shift'] ?? 'am';
if (!in_array($shift, ['am', 'pm', 'night'], true)) fail('invalid shift');

$staffId = (int)$auth['sub'];

$stmt = db()->prepare(
    'INSERT INTO handover_notes (home_id, staff_id, shift, content)
     VALUES (?, ?, ?, ?)'
);
$stmt->execute([(int)$auth['home'], $staffId, $shift, trim($in['content'])]);
$id = (int)db()->lastInsertId();

$row = db()->prepare(
    'SELECT h.id, h.home_id, h.staff_id, h.shift, h.content, h.created_at,
            s.name AS staff_name
       FROM handover_notes h
       LEFT JOIN staff s ON s.id = h.staff_id
      WHERE h.id = ?'
);
$row->execute([$id]);
respond(['note' => $row->fetch()], 201);
