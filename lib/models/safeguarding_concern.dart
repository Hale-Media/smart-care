const List<String> sgCategories = [
  'physical',
  'psychological',
  'financial',
  'neglect',
  'sexual',
  'discriminatory',
  'organisational',
  'domestic',
  'modern_slavery',
  'self_neglect',
];

const List<String> sgStatuses = [
  'raised',
  'under_review',
  'referred',
  'no_referral',
  'closed',
];

String sgCategoryLabel(String c) {
  const map = {
    'physical': 'Physical',
    'psychological': 'Psychological',
    'financial': 'Financial',
    'neglect': 'Neglect',
    'sexual': 'Sexual',
    'discriminatory': 'Discriminatory',
    'organisational': 'Organisational',
    'domestic': 'Domestic abuse',
    'modern_slavery': 'Modern slavery',
    'self_neglect': 'Self-neglect',
  };
  return map[c] ?? c;
}

String sgStatusLabel(String s) {
  const map = {
    'raised': 'Raised',
    'under_review': 'Under review',
    'referred': 'Referred to LA',
    'no_referral': 'No referral',
    'closed': 'Closed',
  };
  return map[s] ?? s;
}

class SafeguardingConcern {
  final int id;
  final int homeId;
  final int? residentId;
  final String category;
  final String description;
  final String status;
  final int? linkedIncidentId;
  final int raisedBy;
  final DateTime raisedAt;
  final String? raisedByName;
  final String? managerReview;
  final bool laReferred;
  final String? laReference;
  final DateTime? referredAt;
  final bool cqcNotified;
  final String? outcome;
  final DateTime? closedAt;

  const SafeguardingConcern({
    required this.id,
    required this.homeId,
    this.residentId,
    required this.category,
    required this.description,
    required this.status,
    this.linkedIncidentId,
    required this.raisedBy,
    required this.raisedAt,
    this.raisedByName,
    this.managerReview,
    required this.laReferred,
    this.laReference,
    this.referredAt,
    required this.cqcNotified,
    this.outcome,
    this.closedAt,
  });

  factory SafeguardingConcern.fromJson(Map<String, dynamic> j) =>
      SafeguardingConcern(
        id: _i(j['id']),
        homeId: _i(j['home_id']),
        residentId: _iN(j['resident_id']),
        category: j['category'] as String,
        description: j['description'] as String,
        status: j['status'] as String,
        linkedIncidentId: _iN(j['linked_incident_id']),
        raisedBy: _i(j['raised_by']),
        raisedAt: j['raised_at'] != null
            ? DateTime.parse(j['raised_at'] as String)
            : DateTime.now(),
        raisedByName: j['raised_by_name'] as String?,
        managerReview: j['manager_review'] as String?,
        laReferred: j['la_referred'] == 1 || j['la_referred'] == true,
        laReference: j['la_reference'] as String?,
        referredAt: j['referred_at'] != null
            ? DateTime.parse(j['referred_at'] as String)
            : null,
        cqcNotified: j['cqc_notified'] == 1 || j['cqc_notified'] == true,
        outcome: j['outcome'] as String?,
        closedAt: j['closed_at'] != null
            ? DateTime.parse(j['closed_at'] as String)
            : null,
      );

  static int _i(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static int? _iN(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }
}
