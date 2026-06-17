<?php
// GET /medications/mar_due.php?from=ISO&to=ISO
// Returns all scheduled (non-PRN) medication slots for today within the time
// window, with their MAR administration status.
require __DIR__ . '/../config.php';
$auth = require_auth();

$fromStr = $_GET['from'] ?? (date('Y-m-d') . ' 00:00:00');
$toStr   = $_GET['to']   ?? (date('Y-m-d') . ' 23:59:59');

$fromDt = new DateTime($fromStr);
$toDt   = new DateTime($toStr);
$today  = $fromDt->format('Y-m-d');

// Active, non-PRN medications for this home's residents today
$stmt = db()->prepare(
    "SELECT m.id, m.resident_id, m.name, m.dose, m.times, m.controlled_drug,
            CONCAT(r.first_name, ' ', r.last_name) AS resident_name
     FROM medications m
     JOIN residents r ON r.id = m.resident_id
     WHERE m.active = 1 AND m.prn = 0 AND r.home_id = ? AND r.active = 1
       AND (m.start_date IS NULL OR m.start_date <= ?)
       AND (m.end_date   IS NULL OR m.end_date   >= ?)"
);
$stmt->execute([(int)$auth['home'], $today, $today]);
$meds = $stmt->fetchAll();

// Today's MAR entries for this home
$marStmt = db()->prepare(
    "SELECT me.id, me.medication_id, me.scheduled_for,
            me.administered_at, me.outcome,
            s.name AS administered_by_name
     FROM mar_entries me
     JOIN medications m ON m.id = me.medication_id
     JOIN residents  r ON r.id = m.resident_id
     LEFT JOIN staff s ON s.id = me.administered_by
     WHERE r.home_id = ? AND DATE(me.scheduled_for) = ?"
);
$marStmt->execute([(int)$auth['home'], $today]);

// Build lookup: medication_id -> [HH:MM -> row]
$marMap = [];
foreach ($marStmt->fetchAll() as $row) {
    $t = (new DateTime($row['scheduled_for']))->format('H:i');
    $marMap[(int)$row['medication_id']][$t] = $row;
}

$slots = [];
foreach ($meds as $med) {
    $rawTimes = array_filter(array_map('trim', explode(',', $med['times'] ?? '')));
    foreach ($rawTimes as $t) {
        $slotDt = new DateTime("$today $t");
        if ($slotDt < $fromDt || $slotDt > $toDt) continue;

        $hm    = $slotDt->format('H:i');
        $entry = $marMap[(int)$med['id']][$hm] ?? null;

        $slots[] = [
            'medication_id'   => (int)$med['id'],
            'resident_id'     => (int)$med['resident_id'],
            'resident_name'   => $med['resident_name'],
            'name'            => $med['name'],
            'dose'            => $med['dose'],
            'controlled_drug' => (bool)$med['controlled_drug'],
            'scheduled_for'   => $slotDt->format('Y-m-d H:i:s'),
            'given'           => $entry !== null,
            'mar_entry_id'    => $entry ? (int)$entry['id'] : null,
            'outcome'         => $entry['outcome'] ?? null,
            'given_by_name'   => $entry['administered_by_name'] ?? null,
            'given_at'        => $entry['administered_at'] ?? null,
        ];
    }
}

usort($slots, fn($a, $b) => strcmp($a['scheduled_for'], $b['scheduled_for']));
respond(['slots' => $slots]);
