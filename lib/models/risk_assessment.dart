import 'package:intl/intl.dart';

const List<String> riskAssessmentTypes = [
  'falls', 'waterlow', 'purpose_t', 'must', 'moving_handling',
  'dols', 'choking', 'behaviour', 'other',
];

const List<String> riskLevels = ['low', 'medium', 'high', 'very_high'];

String riskTypeLabel(String t) {
  const map = {
    'falls': 'Falls',
    'waterlow': 'Waterlow (pressure)',
    'purpose_t': 'PURPOSE-T',
    'must': 'MUST (nutrition)',
    'moving_handling': 'Moving & handling',
    'dols': 'DoLS',
    'choking': 'Choking',
    'behaviour': 'Behaviour',
    'other': 'Other',
  };
  return map[t] ?? t;
}

String riskLevelLabel(String l) {
  const map = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'very_high': 'Very high',
  };
  return map[l] ?? l;
}

class RiskAssessment {
  final int id;
  final int homeId;
  final int residentId;
  final String type;
  final String? toolVersion;
  final int? totalScore;
  final String riskLevel;
  final Map<String, dynamic>? detail;
  final String? summary;
  final DateTime assessedAt;
  final DateTime? reviewDue;
  final int versionNo;
  final int? supersedesId;
  final String status;
  final int rowVersion;
  final DateTime createdAt;

  const RiskAssessment({
    required this.id,
    required this.homeId,
    required this.residentId,
    required this.type,
    this.toolVersion,
    this.totalScore,
    required this.riskLevel,
    this.detail,
    this.summary,
    required this.assessedAt,
    this.reviewDue,
    required this.versionNo,
    this.supersedesId,
    required this.status,
    required this.rowVersion,
    required this.createdAt,
  });

  bool get isOverdue =>
      reviewDue != null && reviewDue!.isBefore(DateTime.now());

  String get reviewDueLabel => reviewDue == null
      ? '—'
      : DateFormat('d MMM yyyy').format(reviewDue!);

  String get assessedAtLabel => DateFormat('d MMM yyyy').format(assessedAt);

  factory RiskAssessment.fromJson(Map<String, dynamic> j) => RiskAssessment(
    id: _i(j['id']),
    homeId: _i(j['home_id']),
    residentId: _i(j['resident_id']),
    type: j['type'] as String,
    toolVersion: j['tool_version'] as String?,
    totalScore: _iN(j['total_score']),
    riskLevel: j['risk_level'] as String,
    detail: j['detail'] is Map<String, dynamic>
        ? j['detail'] as Map<String, dynamic>
        : null,
    summary: j['summary'] as String?,
    assessedAt: j['assessed_at'] != null
        ? DateTime.parse(j['assessed_at'] as String)
        : DateTime.now(),
    reviewDue: j['review_due'] != null
        ? DateTime.parse(j['review_due'] as String)
        : null,
    versionNo: _i(j['version_no'], fallback: 1),
    supersedesId: _iN(j['supersedes_id']),
    status: j['status'] as String,
    rowVersion: _i(j['row_version'], fallback: 1),
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'home_id': homeId,
    'resident_id': residentId,
    'type': type,
    'tool_version': toolVersion,
    'total_score': totalScore,
    'risk_level': riskLevel,
    'detail': detail,
    'summary': summary,
    'assessed_at': assessedAt.toIso8601String(),
    'review_due': reviewDue != null
        ? DateFormat('yyyy-MM-dd').format(reviewDue!)
        : null,
    'version_no': versionNo,
    'supersedes_id': supersedesId,
    'status': status,
    'row_version': rowVersion,
    'created_at': createdAt.toIso8601String(),
  };
}
