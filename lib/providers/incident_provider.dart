import 'package:flutter/foundation.dart';
import '../services/incident_service.dart';

class IncidentProvider extends ChangeNotifier {
  final _service = IncidentService();
  int _openCount = 0;
  bool _loading = false;

  int get openCount => _openCount;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final all = await _service.list();
      _openCount = all.where((i) => i.status != 'closed').length;
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }
}
