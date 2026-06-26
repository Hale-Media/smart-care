import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/resident.dart';
import '../services/resident_service.dart';

class ResidentProvider extends ChangeNotifier {
  static const _cacheKey = 'cache_residents_v1';

  final _service = ResidentService();
  List<Resident> _residents = [];
  bool _loading = false;
  String? _error;
  bool _stale = false;

  List<Resident> get residents => _residents;
  bool get loading => _loading;
  String? get error => _error;
  bool get isStale => _stale;

  Resident? byId(int id) {
    for (final r in _residents) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> load({int? homeId}) async {
    _loading = true;
    _error = null;
    _stale = false;
    notifyListeners();
    try {
      _residents = await _service.list(homeId: homeId);
      _persist(_residents);
    } catch (e) {
      final cached = await _loadCache();
      if (cached != null) {
        _residents = cached;
        _stale = true;
      } else {
        _error = e.toString();
        _residents = [];
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Resident?> save(Resident r) async {
    try {
      final saved = await _service.save(r);
      final idx = _residents.indexWhere((e) => e.id == saved.id);
      if (idx >= 0) {
        _residents[idx] = saved;
      } else {
        _residents.add(saved);
      }
      _persist(_residents);
      notifyListeners();
      return saved;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> _persist(List<Resident> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey, jsonEncode(list.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  Future<List<Resident>?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Resident.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
