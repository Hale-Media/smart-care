<?php
// POST /vitals/record.php
require __DIR__ . '/../config.php';
require __DIR__ . '/_news2.php';
$auth = require_auth();
$in = json_input();
$residentId = (int)($in['resident_id'] ?? 0);
if ($residentId === 0) fail('resident_id is required');

// NEWS2 computed server-side too, so reports/queries don't depend on the client.
$news2 = news2_score($in);

$stmt = db()->prepare(
    'INSERT INTO vitals
       (resident_id, recorded_by, respiratory_rate, spo2, on_oxygen, temperature,
        systolic_bp, heart_rate, consciousness, blood_glucose, news2_score, notes)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?)'
);
$stmt->execute([
    $residentId,
    (int)$auth['sub'],
    $in['respiratory_rate'] ?? null,
    $in['spo2'] ?? null,
    !empty($in['on_oxygen']) ? 1 : 0,
    $in['temperature'] ?? null,
    $in['systolic_bp'] ?? null,
    $in['heart_rate'] ?? null,
    $in['consciousness'] ?? 'A',
    $in['blood_glucose'] ?? null,
    $news2,
    $in['notes'] ?? null,
]);
$id = (int)db()->lastInsertId();
audit((int)$auth['sub'], 'record', 'vital', $id, "NEWS2=$news2");

// Auto-raise an alert when the score signals deterioration.
if ($news2 >= 5) {
    db()->prepare(
        'INSERT INTO alerts (home_id, resident_id, type, severity, status, source, message)
         VALUES (?,?,?,?,?,?,?)'
    )->execute([
        (int)$auth['home'], $residentId, 'vitalsDeterioration',
        $news2 >= 7 ? 'critical' : 'high', 'active', 'vitals',
        "NEWS2 score $news2",
    ]);
}

respond(['vital' => ['id' => $id, 'news2_score' => $news2] + $in], 201);
