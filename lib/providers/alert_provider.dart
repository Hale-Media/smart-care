import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/care_alert.dart';
import '../services/alert_service.dart';
import '../services/notification_service.dart';

class AlertProvider extends ChangeNotifier {
  static const _cacheKey = 'cache_alerts_v1';

  final _service = AlertService();
  List<CareAlert> _alerts = [];
  bool _loading = false;
  String? _error;
  bool _stale = false;
  Timer? _poll;
  int _lastSeenId = 0;

  List<CareAlert> get alerts => _alerts;
  List<CareAlert> get open => _alerts.where((a) => a.isOpen).toList();
  int get openCount => open.length;
  int get criticalCount =>
      open.where((a) => a.severity == 'critical').length;
  bool get loading => _loading;
  String? get error => _error;
  bool get isStale => _stale;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _stale = false;
    notifyListeners();
    try {
      _alerts = await _service.list();
      _alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _persist(_alerts);
    } catch (e) {
      final cached = await _loadCache();
      if (cached != null) {
        _alerts = cached;
        _stale = true;
      } else {
        _error = e.toString();
      }
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
      _stale = false;
      _persist(_alerts);
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

  Future<void> _persist(List<CareAlert> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey, jsonEncode(list.map((a) => a.toJson()).toList()));
    } catch (_) {}
  }

  Future<List<CareAlert>?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => CareAlert.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
