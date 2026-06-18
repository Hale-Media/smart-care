import 'package:intl/intl.dart';

const List<String> carePlanDomains = [
  'mobility', 'nutrition', 'hydration', 'skin', 'continence', 'communication',
  'mental_health', 'social', 'personal_care', 'medication', 'end_of_life', 'other',
];

String domainLabel(String d) {
  const map = {
    'mobility': 'Mobility',
    'nutrition': 'Nutrition',
    'hydration': 'Hydration',
    'skin': 'Skin integrity',
    'continence': 'Continence',
    'communication': 'Communication',
    'mental_health': 'Mental health',
    'social': 'Social & wellbeing',
    'personal_care': 'Personal care',
    'medication': 'Medication',
    'end_of_life': 'End of life',
    'other': 'Other',
  };
  return map[d] ?? d;
}

class CarePlanSection {
  final int id;
  final int homeId;
  final int residentId;
  final String domain;
  final String title;
  final String? whatMattersToMe;
  final String howToSupportMe;
  final String? goals;
  final String? agreedWith;
  final int versionNo;
  final int? supersedesId;
  final String status;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final DateTime? reviewDue;
  final int rowVersion;
  final DateTime createdAt;

  const CarePlanSection({
    required this.id,
    required this.homeId,
    required this.residentId,
    required this.domain,
    required this.title,
    this.whatMattersToMe,
    required this.howToSupportMe,
    this.goals,
    this.agreedWith,
    required this.versionNo,
    this.supersedesId,
    required this.status,
    required this.effectiveFrom,
    this.effectiveTo,
    this.reviewDue,
    required this.rowVersion,
    required this.createdAt,
  });

  bool get isOverdue =>
      reviewDue != null && reviewDue!.isBefore(DateTime.now());

  String get reviewDueLabel => reviewDue == null
      ? '—'
      : DateFormat('d MMM yyyy').format(reviewDue!);

  factory CarePlanSection.fromJson(Map<String, dynamic> j) => CarePlanSection(
    id: _i(j['id']),
    homeId: _i(j['home_id']),
    residentId: _i(j['resident_id']),
    domain: j['domain'] as String,
    title: j['title'] as String,
    whatMattersToMe: j['what_matters_to_me'] as String?,
    howToSupportMe: j['how_to_support_me'] as String,
    goals: j['goals'] as String?,
    agreedWith: j['agreed_with'] as String?,
    versionNo: _i(j['version_no'], fallback: 1),
    supersedesId: _iN(j['supersedes_id']),
    status: j['status'] as String,
    effectiveFrom: j['effective_from'] != null
        ? DateTime.parse(j['effective_from'] as String)
        : DateTime.now(),
    effectiveTo: j['effective_to'] != null
        ? DateTime.parse(j['effective_to'] as String)
        : null,
    reviewDue: j['review_due'] != null
        ? DateTime.parse(j['review_due'] as String)
        : null,
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
    'domain': domain,
    'title': title,
    'what_matters_to_me': whatMattersToMe,
    'how_to_support_me': howToSupportMe,
    'goals': goals,
    'agreed_with': agreedWith,
    'version_no': versionNo,
    'supersedes_id': supersedesId,
    'status': status,
    'effective_from': effectiveFrom.toIso8601String(),
    'effective_to': effectiveTo?.toIso8601String(),
    'review_due': reviewDue != null
        ? DateFormat('yyyy-MM-dd').format(reviewDue!)
        : null,
    'row_version': rowVersion,
    'created_at': createdAt.toIso8601String(),
  };
}
