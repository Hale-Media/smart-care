import '../models/care_alert.dart';
import 'api_client.dart';

class AlertService {
  final _api = ApiClient.instance;

  Future<List<CareAlert>> list({bool openOnly = false}) async {
    final res = await _api.get('/alerts/list.php',
        query: {if (openOnly) 'open': 1});
    final items = (res['alerts'] as List? ?? []);
    return items.map((e) => CareAlert.fromJson(e)).toList();
  }

  Future<CareAlert> create(CareAlert a) async {
    final res = await _api.post('/alerts/create.php', a.toJson());
    return CareAlert.fromJson(res['alert']);
  }

  Future<void> acknowledge(int id, int staffId) =>
      _api.post('/alerts/acknowledge.php', {'id': id, 'staff_id': staffId});

  Future<void> resolve(int id, {String? notes}) =>
      _api.post('/alerts/resolve.php', {'id': id, 'notes': notes});

  Future<void> escalate(int id) =>
      _api.post('/alerts/escalate.php', {'id': id});
}
