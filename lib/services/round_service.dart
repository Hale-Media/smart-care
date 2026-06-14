import '../models/care_round.dart';
import 'api_client.dart';

class RoundService {
  final _api = ApiClient.instance;

  Future<List<CareRound>> due({DateTime? from, DateTime? to}) async {
    final res = await _api.get('/rounds/due.php', query: {
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    });
    final items = (res['rounds'] as List? ?? []);
    return items.map((e) => CareRound.fromJson(e)).toList();
  }

  Future<CareRound> complete(CareRound r) async {
    final res = await _api.post('/rounds/complete.php', r.toJson());
    return CareRound.fromJson(res['round']);
  }

  Future<void> schedule({
    required int residentId,
    required String type,
    required int intervalHours,
    required DateTime startAt,
    required int count,
  }) =>
      _api.post('/rounds/schedule.php', {
        'resident_id': residentId,
        'type': type,
        'interval_hours': intervalHours,
        'start_at': startAt.toIso8601String(),
        'count': count,
      });

  Future<List<CareRound>> history({
    required DateTime from,
    required DateTime to,
    int? residentId,
  }) async {
    final res = await _api.get('/rounds/history.php', query: {
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
      if (residentId != null) 'resident_id': residentId.toString(),
    });
    final items = (res['rounds'] as List? ?? []);
    return items.map((e) => CareRound.fromJson(e)).toList();
  }
}
