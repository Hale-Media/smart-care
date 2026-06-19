const List<String> lpTypes = [
  'lpa_health',
  'lpa_property',
  'deputy',
  'appointee',
];

String lpTypeLabel(String t) {
  const map = {
    'lpa_health': 'LPA — Health & welfare',
    'lpa_property': 'LPA — Property & finance',
    'deputy': 'Court of Protection deputy',
    'appointee': 'DWP appointee',
  };
  return map[t] ?? t;
}

class LastingPower {
  final int id;
  final int homeId;
  final int residentId;
  final String type;
  final String attorneyName;
  final String? attorneyContact;
  final bool registered;
  final String? reference;
  final String? notes;
  final int recordedBy;
  final DateTime createdAt;

  const LastingPower({
    required this.id,
    required this.homeId,
    required this.residentId,
    required this.type,
    required this.attorneyName,
    this.attorneyContact,
    required this.registered,
    this.reference,
    this.notes,
    required this.recordedBy,
    required this.createdAt,
  });

  factory LastingPower.fromJson(Map<String, dynamic> j) => LastingPower(
        id: _i(j['id']),
        homeId: _i(j['home_id']),
        residentId: _i(j['resident_id']),
        type: j['type'] as String,
        attorneyName: j['attorney_name'] as String,
        attorneyContact: j['attorney_contact'] as String?,
        registered: j['registered'] == 1 || j['registered'] == true,
        reference: j['reference'] as String?,
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
