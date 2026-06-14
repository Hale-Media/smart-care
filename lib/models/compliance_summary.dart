/// Aggregated compliance data returned by /compliance/summary.php
class ComplianceSummary {
  final List<ComplianceResident> overdueReviews;
  final List<ComplianceConsentGap> consentGaps;
  final List<ComplianceHighRisk> highRisk;
  final List<ComplianceMissedVisit> missedVisits;
  final List<ComplianceStaffIssue> staffIssues;
  final DateTime fetchedAt;

  const ComplianceSummary({
    required this.overdueReviews,
    required this.consentGaps,
    required this.highRisk,
    required this.missedVisits,
    required this.staffIssues,
    required this.fetchedAt,
  });

  int get totalIssues =>
      overdueReviews.length +
      consentGaps.length +
      highRisk.length +
      missedVisits.length +
      staffIssues.length;

  factory ComplianceSummary.fromJson(Map<String, dynamic> j) =>
      ComplianceSummary(
        overdueReviews: (j['overdue_reviews'] as List? ?? [])
            .map((e) => ComplianceResident.fromJson(e))
            .toList(),
        consentGaps: (j['consent_gaps'] as List? ?? [])
            .map((e) => ComplianceConsentGap.fromJson(e))
            .toList(),
        highRisk: (j['high_risk'] as List? ?? [])
            .map((e) => ComplianceHighRisk.fromJson(e))
            .toList(),
        missedVisits: (j['missed_visits'] as List? ?? [])
            .map((e) => ComplianceMissedVisit.fromJson(e))
            .toList(),
        staffIssues: (j['staff_issues'] as List? ?? [])
            .map((e) => ComplianceStaffIssue.fromJson(e))
            .toList(),
        fetchedAt: j['fetched_at'] != null
            ? DateTime.tryParse(j['fetched_at']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class ComplianceResident {
  final int id;
  final String firstName;
  final String lastName;
  final DateTime? outcomeReviewDate;
  final String careLevel;

  const ComplianceResident({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.careLevel,
    this.outcomeReviewDate,
  });

  String get fullName => '$firstName $lastName';

  factory ComplianceResident.fromJson(Map<String, dynamic> j) =>
      ComplianceResident(
        id: j['id'] as int,
        firstName: j['first_name'] ?? '',
        lastName: j['last_name'] ?? '',
        careLevel: j['care_level'] ?? '',
        outcomeReviewDate: j['outcome_review_date'] != null
            ? DateTime.tryParse(j['outcome_review_date'])
            : null,
      );
}

class ComplianceConsentGap {
  final int id;
  final String firstName;
  final String lastName;
  final String monitoringMethods;
  final String monitoringConsent;

  const ComplianceConsentGap({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.monitoringMethods,
    required this.monitoringConsent,
  });

  String get fullName => '$firstName $lastName';

  factory ComplianceConsentGap.fromJson(Map<String, dynamic> j) =>
      ComplianceConsentGap(
        id: j['id'] as int,
        firstName: j['first_name'] ?? '',
        lastName: j['last_name'] ?? '',
        monitoringMethods: j['monitoring_methods'] ?? '',
        monitoringConsent: j['monitoring_consent'] ?? '',
      );
}

class ComplianceHighRisk {
  final int id;
  final String firstName;
  final String lastName;
  final String fallRisk;
  final String nutritionRisk;

  const ComplianceHighRisk({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fallRisk,
    required this.nutritionRisk,
  });

  String get fullName => '$firstName $lastName';

  factory ComplianceHighRisk.fromJson(Map<String, dynamic> j) =>
      ComplianceHighRisk(
        id: j['id'] as int,
        firstName: j['first_name'] ?? '',
        lastName: j['last_name'] ?? '',
        fallRisk: j['fall_risk'] ?? 'low',
        nutritionRisk: j['nutrition_risk'] ?? 'low',
      );
}

class ComplianceMissedVisit {
  final int id;
  final int residentId;
  final String firstName;
  final String lastName;
  final String scheduledTime;

  const ComplianceMissedVisit({
    required this.id,
    required this.residentId,
    required this.firstName,
    required this.lastName,
    required this.scheduledTime,
  });

  String get fullName => '$firstName $lastName';

  factory ComplianceMissedVisit.fromJson(Map<String, dynamic> j) =>
      ComplianceMissedVisit(
        id: j['id'] as int,
        residentId: j['resident_id'] as int,
        firstName: j['first_name'] ?? '',
        lastName: j['last_name'] ?? '',
        scheduledTime: j['scheduled_time'] ?? '',
      );
}

class ComplianceStaffIssue {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? monitoringCompetency;
  final DateTime? competencyReviewDate;

  const ComplianceStaffIssue({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.monitoringCompetency,
    this.competencyReviewDate,
  });

  bool get hasNoRecord => monitoringCompetency == null;
  bool get isOverdue =>
      competencyReviewDate != null &&
      competencyReviewDate!.isBefore(DateTime.now());

  factory ComplianceStaffIssue.fromJson(Map<String, dynamic> j) =>
      ComplianceStaffIssue(
        id: j['id'] as int,
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        role: j['role'] ?? '',
        monitoringCompetency: j['monitoring_competency'],
        competencyReviewDate: j['competency_review_date'] != null
            ? DateTime.tryParse(j['competency_review_date'])
            : null,
      );
}
