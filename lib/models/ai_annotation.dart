enum AiEntity {
  careCall('care_call'),
  handoverNote('handover_note'),
  incident('incident');

  const AiEntity(this.value);
  final String value;

  static AiEntity? fromValue(String v) {
    for (final e in values) {
      if (e.value == v) return e;
    }
    return null;
  }
}

class AiAnnotation {
  final int id;
  final AiEntity entity;
  final int entityId;
  final String? summary;
  final List<String> riskFlags;
  final String? mood;
  final bool followUp;
  final String? modelName;
  final String? modelSha256;
  final String reviewState; // 'pending' | 'confirmed' | 'dismissed'
  final int? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const AiAnnotation({
    required this.id,
    required this.entity,
    required this.entityId,
    this.summary,
    required this.riskFlags,
    this.mood,
    required this.followUp,
    this.modelName,
    this.modelSha256,
    required this.reviewState,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });

  factory AiAnnotation.fromJson(Map<String, dynamic> j) => AiAnnotation(
        id: j['id'] as int,
        entity: AiEntity.fromValue(j['entity'] as String? ?? '') ?? AiEntity.careCall,
        entityId: j['entity_id'] as int,
        summary: j['summary'] as String?,
        riskFlags: (j['risk_flags'] as List? ?? []).cast<String>(),
        mood: j['mood'] as String?,
        followUp: j['follow_up'] == true || j['follow_up'] == 1,
        modelName: j['model_name'] as String?,
        modelSha256: j['model_sha256'] as String?,
        reviewState: j['review_state'] as String? ?? 'pending',
        reviewedBy: j['reviewed_by'] as int?,
        reviewedAt: j['reviewed_at'] != null
            ? DateTime.parse(j['reviewed_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
