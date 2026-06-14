<?php
// GET /compliance/summary.php
// Aggregated compliance items for the active home. Manager/admin only.
require __DIR__ . '/../config.php';
$auth = require_auth();
if (!in_array($auth['role'] ?? '', ['manager', 'admin', 'nurse', 'seniorCarer'], true)) {
    fail('Insufficient permissions', 403);
}
$homeId    = (int)$auth['home'];
$companyId = (int)($auth['company'] ?? 0);
$now       = new DateTimeImmutable();
$today     = $now->format('Y-m-d');
$nowTime   = $now->format('H:i:s');

// Helper: prepare + execute a query, returning [] if columns/tables don't exist yet
// (guards against compliance migrations not yet applied on the server).
function safe_query(string $sql, array $params): array {
    try {
        $stmt = db()->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    } catch (PDOException $e) {
        // 42S02 = table not found, 42S22 = column not found — migration pending.
        if (in_array($e->getCode(), ['42S02', '42S22'], true)) {
            return [];
        }
        throw $e;
    }
}

// 1. Residents with overdue outcome review (review date < today).
$overdueReviews = safe_query(
    'SELECT id, first_name, last_name, outcome_review_date, care_level
     FROM residents
     WHERE home_id = ? AND active = 1
       AND outcome_review_date IS NOT NULL AND outcome_review_date < ?
     ORDER BY outcome_review_date ASC',
    [$homeId, $today]
);

// 2. Consent gaps — camera / recording in use without documented consent.
$consentGaps = safe_query(
    "SELECT id, first_name, last_name, monitoring_methods, monitoring_consent
     FROM residents
     WHERE home_id = ? AND active = 1
       AND monitoring_methods LIKE '%camera%'
       AND monitoring_consent IN ('not_required','declined')",
    [$homeId]
);

// 3. High-risk residents — fall risk or nutrition risk rated high.
$highRisk = safe_query(
    "SELECT id, first_name, last_name, fall_risk, nutrition_risk
     FROM residents
     WHERE home_id = ? AND active = 1
       AND (fall_risk = 'high' OR nutrition_risk = 'high')
     ORDER BY last_name, first_name",
    [$homeId]
);

// 4. Missed domiciliary visits — unconfirmed calls whose scheduled time has passed.
$missedVisits = safe_query(
    'SELECT cc.id, cc.scheduled_time,
            r.id AS resident_id, r.first_name, r.last_name
     FROM care_calls cc
     JOIN residents r ON r.id = cc.resident_id
     WHERE r.home_id = ? AND cc.scheduled_date = ?
       AND cc.confirmed = 0 AND cc.scheduled_time < ?
     ORDER BY cc.scheduled_time ASC',
    [$homeId, $today, $nowTime]
);

// 5. Staff competency issues — active staff with overdue or missing competency records.
$staffIssues = safe_query(
    'SELECT id, name, email, role, monitoring_competency, competency_review_date
     FROM staff
     WHERE company_id = ? AND active = 1
       AND (
             competency_review_date < ?
             OR (competency_review_date IS NULL AND monitoring_competency IS NULL)
           )
     ORDER BY name',
    [$companyId, $today]
);

respond([
    'overdue_reviews' => $overdueReviews,
    'consent_gaps'    => $consentGaps,
    'high_risk'       => $highRisk,
    'missed_visits'   => $missedVisits,
    'staff_issues'    => $staffIssues,
    'fetched_at'      => $now->format('c'),
]);
