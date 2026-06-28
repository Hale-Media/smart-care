import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/widgets.dart';

import '../../../services/api_client.dart';
import 'annotation_queue.dart';

/// Drains the local annotation queue to the server.
///
/// Runs on three triggers:
///   1. Immediately when [start] is called.
///   2. Every [interval] (default 5 min) via a periodic timer.
///   3. Each time the app returns to the foreground.
class AnnotationSyncWorker {
  final AnnotationQueueStore store;
  final ApiClient _api;
  final Duration interval;

  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _draining = false;

  AnnotationSyncWorker({
    required this.store,
    ApiClient? api,
    this.interval = const Duration(minutes: 5),
  }) : _api = api ?? ApiClient.instance;

  void start() {
    _timer = Timer.periodic(interval, (_) => drain());
    _lifecycle = AppLifecycleListener(onResume: drain);
    drain();
  }

  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final items = await store.pending();
      for (final item in items) {
        try {
          await _api.put('/ai_annotation_upsert.php', item.toServerJson());
          await store.markSynced(item.id!);
          dev.log('synced annotation ${item.id}', name: 'AnnotationSyncWorker');
        } catch (e) {
          await store.incrementRetry(item.id!);
          dev.log('retry++ for ${item.id}: $e',
              name: 'AnnotationSyncWorker');
          break; // stop on first failure — avoid hammering an unreachable server
        }
      }
    } catch (e) {
      dev.log('drain error: $e', name: 'AnnotationSyncWorker');
    } finally {
      _draining = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    _timer = null;
    _lifecycle = null;
  }
}
