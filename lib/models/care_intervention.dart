class CareIntervention {
  final int id;
  final int homeId;
  final int residentId;
  final int sectionId;
  final int? riskAssessmentId;
  final String description;
  final String? frequency;
  final String status;

  const CareIntervention({
    required this.id,
    required this.homeId,
    required this.residentId,
    required this.sectionId,
    this.riskAssessmentId,
    required this.description,
    this.frequency,
    required this.status,
  });

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory CareIntervention.fromJson(Map<String, dynamic> j) => CareIntervention(
    id: _i(j['id']),
    homeId: _i(j['home_id']),
    residentId: _i(j['resident_id']),
    sectionId: _i(j['section_id']),
    riskAssessmentId: j['risk_assessment_id'] == null ? null : _i(j['risk_assessment_id']),
    description: j['description'] as String,
    frequency: j['frequency'] as String?,
    status: j['status'] as String,
  );
}
