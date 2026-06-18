class CareIntervention {
  final int id;
  final int homeId;
  final int residentId;
  final int sectionId;
  final int? riskAssessmentId;
  final String description;
  final String? frequency;
  final String status;
  final int rowVersion;

  const CareIntervention({
    required this.id,
    required this.homeId,
    required this.residentId,
    required this.sectionId,
    this.riskAssessmentId,
    required this.description,
    this.frequency,
    required this.status,
    required this.rowVersion,
  });

  factory CareIntervention.fromJson(Map<String, dynamic> j) => CareIntervention(
    id: j['id'] as int,
    homeId: j['home_id'] as int,
    residentId: j['resident_id'] as int,
    sectionId: j['section_id'] as int,
    riskAssessmentId: j['risk_assessment_id'] as int?,
    description: j['description'] as String,
    frequency: j['frequency'] as String?,
    status: j['status'] as String,
    rowVersion: j['row_version'] as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'home_id': homeId,
    'resident_id': residentId,
    'section_id': sectionId,
    'risk_assessment_id': riskAssessmentId,
    'description': description,
    'frequency': frequency,
    'status': status,
    'row_version': rowVersion,
  };
}
