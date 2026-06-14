import '../models/resident.dart';
import 'api_client.dart';

class ResidentService {
  final _api = ApiClient.instance;

  Future<List<Resident>> list({bool activeOnly = true, int? homeId}) async {
    final query = <String, dynamic>{'active': activeOnly ? 1 : 0};
    if (homeId != null) query['home_id'] = homeId;
    final res = await _api.get('/residents/list.php', query: query);
    final items = (res['residents'] as List? ?? []);
    return items.map((e) => Resident.fromJson(e)).toList();
  }

  Future<Resident> get(int id) async {
    final res = await _api.get('/residents/get.php', query: {'id': id});
    return Resident.fromJson(res['resident']);
  }

  Future<Resident> save(Resident r) async {
    final res = r.id == 0
        ? await _api.post('/residents/create.php', r.toJson())
        : await _api.put('/residents/update.php', r.toJson());
    return Resident.fromJson(res['resident']);
  }

  Future<void> discharge(int id) =>
      _api.post('/residents/discharge.php', {'id': id});
}
