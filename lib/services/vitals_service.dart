import '../models/vital_reading.dart';
import 'api_client.dart';

class VitalsService {
  final _api = ApiClient.instance;

  Future<List<VitalReading>> history(int residentId, {int limit = 50}) async {
    final res = await _api.get('/vitals/history.php',
        query: {'resident_id': residentId, 'limit': limit});
    final items = (res['vitals'] as List? ?? []);
    return items.map((e) => VitalReading.fromJson(e)).toList();
  }

  Future<VitalReading> record(VitalReading v) async {
    final res = await _api.post('/vitals/record.php', v.toJson());
    return VitalReading.fromJson(res['vital']);
  }
}
