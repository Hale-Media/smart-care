const List<String> adTypes = ['dnacpr', 'respect', 'adrt'];

String adTypeLabel(String t) {
  const map = {
    'dnacpr': 'DNACPR',
    'respect': 'ReSPECT',
    'adrt': 'ADRT',
  };
  return map[t] ?? t;
}

class AdvanceDecision {
  final int id;
  final int homeId;
  final int residentId;
  final String type;
  final bool inPlace;
  final String? formReference;
  final String? completedBy;
  final DateTime? dateCompleted;
  final DateTime? reviewDate;
  final String? location;
  final String? notes;
  final int recordedBy;
  final DateTime createdAt;

  const AdvanceDecision({
    required this.id,
    required this.homeId,
    required this.residentId,
    required this.type,
    required this.inPlace,
    this.formReference,
    this.completedBy,
    this.dateCompleted,
    this.reviewDate,
    this.location,
    this.notes,
    required this.recordedBy,
    required this.createdAt,
  });

  factory AdvanceDecision.fromJson(Map<String, dynamic> j) => AdvanceDecision(
        id: _i(j['id']),
        homeId: _i(j['home_id']),
        residentId: _i(j['resident_id']),
        type: j['type'] as String,
        inPlace: j['in_place'] == 1 || j['in_place'] == true,
        formReference: j['form_reference'] as String?,
        completedBy: j['completed_by'] as String?,
        dateCompleted: j['date_completed'] != null
            ? DateTime.parse(j['date_completed'] as String)
            : null,
        reviewDate: j['review_date'] != null
            ? DateTime.parse(j['review_date'] as String)
            : null,
        location: j['location'] as String?,
        notes: j['notes'] as String?,
        recordedBy: _i(j['recorded_by']),
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
}
