const List<String> doLsStatuses = [
  'not_required',
  'urgent',
  'applied',
  'granted',
  'declined',
  'expired',
  'ended',
];

String doLsStatusLabel(String s) {
  const map = {
    'not_required': 'Not required',
    'urgent': 'Urgent',
    'applied': 'Applied',
    'granted': 'Granted',
    'declined': 'Declined',
    'expired': 'Expired',
    'ended': 'Ended',
  };
  return map[s] ?? s;
}

class DoLsAuthorisation {
  final int id;
  final int homeId;
  final int residentId;
  final String status;
  final bool urgent;
  final String? reference;
  final String? supervisoryBody;
  final DateTime? appliedOn;
  final DateTime? grantedOn;
  final DateTime? expiresOn;
  final String? conditions;
  final String? notes;
  final int recordedBy;
  final DateTime createdAt;

  const DoLsAuthorisation({
    required this.id,
    required this.homeId,
    required this.residentId,
    required this.status,
    required this.urgent,
    this.reference,
    this.supervisoryBody,
    this.appliedOn,
    this.grantedOn,
    this.expiresOn,
    this.conditions,
    this.notes,
    required this.recordedBy,
    required this.createdAt,
  });

  bool get isExpiringSoon {
    if (status != 'granted' || expiresOn == null) return false;
    return expiresOn!.difference(DateTime.now()).inDays <= 30;
  }

  factory DoLsAuthorisation.fromJson(Map<String, dynamic> j) =>
      DoLsAuthorisation(
        id: _i(j['id']),
        homeId: _i(j['home_id']),
        residentId: _i(j['resident_id']),
        status: j['status'] as String,
        urgent: j['urgent'] == 1 || j['urgent'] == true,
        reference: j['reference'] as String?,
        supervisoryBody: j['supervisory_body'] as String?,
        appliedOn: j['applied_on'] != null
            ? DateTime.parse(j['applied_on'] as String)
            : null,
        grantedOn: j['granted_on'] != null
            ? DateTime.parse(j['granted_on'] as String)
            : null,
        expiresOn: j['expires_on'] != null
            ? DateTime.parse(j['expires_on'] as String)
            : null,
        conditions: j['conditions'] as String?,
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
