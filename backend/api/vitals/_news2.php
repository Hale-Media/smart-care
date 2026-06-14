<?php
// Shared NEWS2 calculator — mirrors the Dart logic in VitalReading.news2Score.
function news2_score(array $v): int {
    $score = 0;
    $rr = $v['respiratory_rate'] ?? null;
    if ($rr !== null) {
        if ($rr <= 8) $score += 3;
        elseif ($rr <= 11) $score += 1;
        elseif ($rr <= 20) $score += 0;
        elseif ($rr <= 24) $score += 2;
        else $score += 3;
    }
    $s = $v['spo2'] ?? null;
    if ($s !== null) {
        if ($s <= 91) $score += 3;
        elseif ($s <= 93) $score += 2;
        elseif ($s <= 95) $score += 1;
    }
    if (!empty($v['on_oxygen'])) $score += 2;
    $t = $v['temperature'] ?? null;
    if ($t !== null) {
        if ($t <= 35.0) $score += 3;
        elseif ($t <= 36.0) $score += 1;
        elseif ($t <= 38.0) $score += 0;
        elseif ($t <= 39.0) $score += 1;
        else $score += 2;
    }
    $bp = $v['systolic_bp'] ?? null;
    if ($bp !== null) {
        if ($bp <= 90) $score += 3;
        elseif ($bp <= 100) $score += 2;
        elseif ($bp <= 110) $score += 1;
        elseif ($bp >= 220) $score += 3;
    }
    $hr = $v['heart_rate'] ?? null;
    if ($hr !== null) {
        if ($hr <= 40) $score += 3;
        elseif ($hr <= 50) $score += 1;
        elseif ($hr <= 90) $score += 0;
        elseif ($hr <= 110) $score += 1;
        elseif ($hr <= 130) $score += 2;
        else $score += 3;
    }
    if (strtoupper($v['consciousness'] ?? 'A') !== 'A') $score += 3;
    return $score;
}
