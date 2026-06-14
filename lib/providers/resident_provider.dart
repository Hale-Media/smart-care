import 'package:flutter/foundation.dart';
import '../models/resident.dart';
import '../services/resident_service.dart';

class ResidentProvider extends ChangeNotifier {
  final _service = ResidentService();
  List<Resident> _residents = [];
  bool _loading = false;
  String? _error;

  List<Resident> get residents => _residents;
  bool get loading => _loading;
  String? get error => _error;

  Resident? byId(int id) {
    for (final r in _residents) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> load({int? homeId}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _residents = await _service.list(homeId: homeId);
    } catch (e) {
      _error = e.toString();
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
      notifyListeners();
      return saved;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
