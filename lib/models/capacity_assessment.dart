class CapacityAssessment {
  final int id;
  final int homeId;
  final int residentId;
  final String decision;
  final bool hasCapacity;
  final String? assessmentSummary;
  final String? bestInterests;
  final int assessedBy;
  final DateTime? reviewDue;
  final int versionNo;
  final String status;
  final int? supersedesId;
  final DateTime createdAt;

  const CapacityAssessment({
    required this.id,
    required this.homeId,
    required this.residentId,
    required this.decision,
    required this.hasCapacity,
    this.assessmentSummary,
    this.bestInterests,
    required this.assessedBy,
    this.reviewDue,
    required this.versionNo,
    required this.status,
    this.supersedesId,
    required this.createdAt,
  });

  bool get isOverdue =>
      reviewDue != null && reviewDue!.isBefore(DateTime.now());

  factory CapacityAssessment.fromJson(Map<String, dynamic> j) =>
      CapacityAssessment(
        id: _i(j['id']),
        homeId: _i(j['home_id']),
        residentId: _i(j['resident_id']),
        decision: j['decision'] as String,
        hasCapacity: j['has_capacity'] == 1 || j['has_capacity'] == true,
        assessmentSummary: j['assessment_summary'] as String?,
        bestInterests: j['best_interests'] as String?,
        assessedBy: _i(j['assessed_by']),
        reviewDue: j['review_due'] != null
            ? DateTime.parse(j['review_due'] as String)
            : null,
        versionNo: _i(j['version_no'], fallback: 1),
        status: j['status'] as String,
        supersedesId: _iN(j['supersedes_id']),
        createdAt: j['created_at'] != null
            ? DateTime.parse(j['created_at'] as String)
            : DateTime.now(),
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
