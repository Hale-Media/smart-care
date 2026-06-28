import 'dart:convert';

import '../ai_annotation.dart';

/// A single annotation that failed server sync and is waiting to be sent.
class QueuedAnnotation {
  final int? id; // SQLite rowid, null before insert
  final AiEntity entity;
  final int entityId;
  final String summary;
  final List<String> riskFlags;
  final String mood;
  final bool followUp;
  final String modelName;
  final String modelSha256;
  final DateTime queuedAt;
  final int retryCount;

  const QueuedAnnotation({
    this.id,
    required this.entity,
    required this.entityId,
    required this.summary,
    required this.riskFlags,
    required this.mood,
    required this.followUp,
    required this.modelName,
    required this.modelSha256,
    required this.queuedAt,
    this.retryCount = 0,
  });

  /// Body sent to /ai_annotation_upsert.php.
  Map<String, dynamic> toServerJson() => {
        'entity': entity.value,
        'entity_id': entityId,
        'ai_summary': summary,
        'ai_risk_flags': riskFlags,
        'ai_mood': mood,
        'ai_follow_up': followUp,
        'model_name': modelName,
        'model_sha256': modelSha256,
      };

  Map<String, dynamic> toSqlite() => {
        'entity': entity.value,
        'entity_id': entityId,
        'summary': summary,
        'risk_flags': jsonEncode(riskFlags),
        'mood': mood,
        'follow_up': followUp ? 1 : 0,
        'model_name': modelName,
        'model_sha256': modelSha256,
        'queued_at': queuedAt.toIso8601String(),
        'retry_count': retryCount,
      };

  factory QueuedAnnotation.fromSqlite(Map<String, dynamic> row) =>
      QueuedAnnotation(
        id: row['id'] as int,
        entity:
            AiEntity.fromValue(row['entity'] as String) ?? AiEntity.careCall,
        entityId: row['entity_id'] as int,
        summary: row['summary'] as String,
        riskFlags:
            (jsonDecode(row['risk_flags'] as String) as List).cast<String>(),
        mood: row['mood'] as String,
        followUp: (row['follow_up'] as int) == 1,
        modelName: row['model_name'] as String,
        modelSha256: row['model_sha256'] as String,
        queuedAt: DateTime.parse(row['queued_at'] as String),
        retryCount: row['retry_count'] as int,
      );
}

/// Persistence interface — swap implementation for tests.
abstract class AnnotationQueueStore {
  Future<void> open();
  Future<void> enqueue(QueuedAnnotation item);

  /// Items with fewer than [maxRetries] attempts, oldest first.
  Future<List<QueuedAnnotation>> pending({int maxRetries = 5});

  /// Remove a successfully synced item.
  Future<void> markSynced(int id);

  /// Bump retry counter after a transient failure.
  Future<void> incrementRetry(int id);

  /// How many items are still waiting (below max-retries).
  Future<int> pendingCount();
}
