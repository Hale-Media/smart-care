import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../ai_annotation.dart';
import '../queue/annotation_queue.dart';
import '../queue/annotation_sync_worker.dart';

class ReviewProvider extends ChangeNotifier {
  final ApiClient _api;
  final AnnotationQueueStore _store;
  late final AnnotationSyncWorker _worker;

  List<AiAnnotation> _items = [];
  String _filter = 'pending';
  bool _loading = false;
  int _queuedCount = 0;

  List<AiAnnotation> get items => List.unmodifiable(_items);
  String get filter => _filter;
  bool get loading => _loading;

  /// How many annotations are locally queued (server unreachable at inference time).
  int get queuedCount => _queuedCount;

  ReviewProvider({
    required AnnotationQueueStore queueStore,
    ApiClient? api,
  })  : _api = api ?? ApiClient.instance,
        _store = queueStore {
    _worker = AnnotationSyncWorker(store: _store);
    _worker.start();
  }

  Future<void> load({String? filter}) async {
    if (filter != null) _filter = filter;
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.get(
        '/ai_flags_list.php',
        query: {'state': _filter, 'limit': 50},
      );
      _items = (res['items'] as List? ?? [])
          .map((e) => AiAnnotation.fromJson(e as Map<String, dynamic>))
          .toList();
      _queuedCount = await _store.pendingCount();
    } catch (e) {
      dev.log('ReviewProvider.load failed', name: 'ReviewProvider', error: e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> confirm(int id) => _decide(id, 'confirmed');
  Future<void> dismiss(int id) => _decide(id, 'dismissed');

  Future<void> _decide(int id, String decision) async {
    final idx = _items.indexWhere((a) => a.id == id);
    if (idx == -1) return;

    // Optimistic update
    final original = _items[idx];
    _items[idx] = _patch(original, decision);
    notifyListeners();

    try {
      await _api.post('/ai_annotation_review.php', {
        'id': id,
        'decision': decision,
      });
    } catch (e) {
      // Revert if server rejected
      _items[idx] = original;
      dev.log('_decide failed, reverted', name: 'ReviewProvider', error: e);
      notifyListeners();
    }
  }

  AiAnnotation _patch(AiAnnotation a, String state) => AiAnnotation(
        id: a.id,
        entity: a.entity,
        entityId: a.entityId,
        summary: a.summary,
        riskFlags: a.riskFlags,
        mood: a.mood,
        followUp: a.followUp,
        modelName: a.modelName,
        modelSha256: a.modelSha256,
        reviewState: state,
        reviewedBy: a.reviewedBy,
        reviewedAt: DateTime.now().toUtc(),
        createdAt: a.createdAt,
      );

  @override
  void dispose() {
    _worker.dispose();
    super.dispose();
  }
}
