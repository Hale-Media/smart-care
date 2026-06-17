import '../models/home_care_call.dart';
import 'api_client.dart';

class HomeCareCallService {
  final _api = ApiClient.instance;

  Future<List<HomeCareCall>> list({
    required int residentId,
    String? date,
  }) async {
    final query = <String, dynamic>{'resident_id': residentId};
    if (date != null) query['date'] = date;
    final res = await _api.get('/care_calls/list.php', query: query);
    return (res['calls'] as List? ?? [])
        .map((e) => HomeCareCall.fromJson(e))
        .toList();
  }

  Future<HomeCareCall> confirm(
    int id, {
    String? notes,
    String? careProvided,
    bool safetyChecked = false,
    String wellbeingStatus = 'stable',
    String? escalatedTo,
    bool promotesIndependence = true,
    bool reviewRequired = false,
  }) async {
    final res = await _api.post('/care_calls/confirm.php', {
      'id': id,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (careProvided != null && careProvided.isNotEmpty)
        'care_provided': careProvided,
      'safety_checked': safetyChecked ? 1 : 0,
      'wellbeing_status': wellbeingStatus,
      if (escalatedTo != null && escalatedTo.isNotEmpty)
        'escalated_to': escalatedTo,
      'promotes_independence': promotesIndependence ? 1 : 0,
      'review_required': reviewRequired ? 1 : 0,
    });
    return HomeCareCall.fromJson(res['call']);
  }

  Future<List<HomeCareCall>> history({
    required DateTime startDate,
    required DateTime endDate,
    int? residentId,
    String? status, // 'confirmed', 'pending', or null for all
  }) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final query = <String, dynamic>{
      'start_date': fmt(startDate),
      'end_date': fmt(endDate),
      'resident_id': residentId,
      'status': status,
    }..removeWhere((_, v) => v == null);
    final res = await _api.get('/care_calls/history.php', query: query);
    return (res['calls'] as List? ?? [])
        .map((e) => HomeCareCall.fromJson(e))
        .toList();
  }

  /// Generates today's expected calls for a resident (upsert on server).
  Future<List<HomeCareCall>> generateToday(int residentId) async {
    final res = await _api.post('/care_calls/generate.php', {
      'resident_id': residentId,
    });
    return (res['calls'] as List? ?? [])
        .map((e) => HomeCareCall.fromJson(e))
        .toList();
  }
}
