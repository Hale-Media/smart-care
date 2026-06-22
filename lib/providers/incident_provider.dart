import 'package:flutter/foundation.dart';
import '../services/incident_service.dart';

class IncidentProvider extends ChangeNotifier {
  final _service = IncidentService();
  int _openCount = 0;
  bool _loading = false;
  String? _error;

  int get openCount => _openCount;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final all = await _service.list();
      _openCount = all.where((i) => i.status != 'closed').length;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }
}
