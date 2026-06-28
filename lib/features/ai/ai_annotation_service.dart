import 'dart:developer' as dev;

import '../../services/api_client.dart';
import 'ai_annotation.dart';
import 'queue/annotation_queue.dart';
import 'queue/sqflite_annotation_queue.dart';

/// Returned by [runAnalysis] — the four fields the on-device model produces.
typedef AnalysisResult = ({
  String summary,
  List<String> riskFlags,
  String mood,
  bool followUp,
});

/// Returned by [modelInfo] — stored for provenance / PDF audit.
typedef ModelInfo = ({String name, String sha});

/// Runs on-device inference, syncs the derived JSON to the server.
/// If the server POST fails the annotation is persisted to a local SQLite
/// queue ([AnnotationQueueStore]) so [AnnotationSyncWorker] can retry it
/// when connectivity is restored.  Resident free text never leaves the device.
class AiAnnotationService {
  final ApiClient _api;
  final Future<AnalysisResult> Function(String text) runAnalysis;
  final Future<ModelInfo> Function() modelInfo;
  final AnnotationQueueStore _queue;

  /// When true, inference runs and is logged but nothing is sent to the server
  /// and nothing is enqueued.
  final bool dryRun;

  AiAnnotationService({
    ApiClient? api,
    required this.runAnalysis,
    required this.modelInfo,
    AnnotationQueueStore? queue,
    this.dryRun = false,
  })  : _api = api ?? ApiClient.instance,
        _queue = queue ?? SqfliteAnnotationQueue.instance;

  /// Run inference on [noteText] and sync (or enqueue) the result.
  ///
  /// Returns an [AiAnnotation] on immediate server success, null otherwise
  /// (dry-run, queued, or inference error).  Never throws — failures are
  /// logged so callers can always continue their own save flow.
  Future<AiAnnotation?> annotate({
    required AiEntity entity,
    required int entityId,
    required String noteText,
  }) async {
    try {
      final result = await runAnalysis(noteText);
      final info = await modelInfo();

      if (dryRun) {
        dev.log(
          'entity=${entity.value} id=$entityId '
          'flags=${result.riskFlags} mood=${result.mood} '
          'followUp=${result.followUp} model=${info.name}',
          name: 'AiAnnotation.dryRun',
        );
        dev.log('summary: ${result.summary}', name: 'AiAnnotation.dryRun');
        return null;
      }

      try {
        final res = await _api.put('/ai_annotation_upsert.php', {
          'entity': entity.value,
          'entity_id': entityId,
          'ai_summary': result.summary,
          'ai_risk_flags': result.riskFlags,
          'ai_mood': result.mood,
          'ai_follow_up': result.followUp,
          'model_name': info.name,
          'model_sha256': info.sha,
        });

        return AiAnnotation(
          id: res['id'] as int,
          entity: entity,
          entityId: entityId,
          summary: result.summary,
          riskFlags: result.riskFlags,
          mood: result.mood,
          followUp: result.followUp,
          modelName: info.name,
          modelSha256: info.sha,
          reviewState: res['review_state'] as String? ?? 'pending',
          reviewedBy: null,
          reviewedAt: null,
          createdAt: DateTime.now().toUtc(),
        );
      } catch (serverErr) {
        dev.log(
          'server sync failed — enqueueing for later retry',
          name: 'AiAnnotation',
          error: serverErr,
        );
        await _queue.enqueue(QueuedAnnotation(
          entity: entity,
          entityId: entityId,
          summary: result.summary,
          riskFlags: result.riskFlags,
          mood: result.mood,
          followUp: result.followUp,
          modelName: info.name,
          modelSha256: info.sha,
          queuedAt: DateTime.now().toUtc(),
        ));
        return null;
      }
    } catch (e, st) {
      dev.log('annotate failed', name: 'AiAnnotation', error: e, stackTrace: st);
      return null;
    }
  }
}
