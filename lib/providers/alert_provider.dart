import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/care_alert.dart';
import '../services/alert_service.dart';
import '../services/notification_service.dart';

class AlertProvider extends ChangeNotifier {
  final _service = AlertService();
  List<CareAlert> _alerts = [];
  bool _loading = false;
  String? _error;
  Timer? _poll;
  int _lastSeenId = 0;

  List<CareAlert> get alerts => _alerts;
  List<CareAlert> get open => _alerts.where((a) => a.isOpen).toList();
  int get openCount => open.length;
  int get criticalCount =>
      open.where((a) => a.severity == 'critical').length;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _alerts = await _service.list();
      _alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Start polling for new alerts (until a realtime transport replaces this).
  void startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(AppConfig.liveRefreshInterval, (_) => _refresh());
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _service.list();
      fresh.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // Notify on newly arrived open alerts.
      for (final a in fresh) {
        if (a.id > _lastSeenId && a.isOpen) {
          await NotificationService.instance.showAlert(
            id: a.id,
            title: a.type.label,
            body: '${a.residentName ?? 'Resident'} · ${a.location ?? ''}',
            critical: a.severity == 'critical',
          );
        }
      }
      if (fresh.isNotEmpty) {
        _lastSeenId = fresh.map((e) => e.id).reduce((a, b) => a > b ? a : b);
      }
      _alerts = fresh;
      notifyListeners();
    } catch (_) {/* swallow transient poll errors */}
  }

  Future<void> acknowledge(int id, int staffId) async {
    await _service.acknowledge(id, staffId);
    await load();
  }

  Future<void> resolve(int id, {String? notes}) async {
    await _service.resolve(id, notes: notes);
    await load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
