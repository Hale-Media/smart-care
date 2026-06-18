import '../models/care_plan_section.dart';
import 'api_client.dart';

class CarePlanService {
  final _api = ApiClient.instance;

  Future<List<CarePlanSection>> activeSections(int residentId) async {
    final res = await _api.get(
      '/care_plans.php',
      query: {'resident_id': residentId},
    );
    final list = (res['sections'] as List? ?? []);
    return list.map((e) => CarePlanSection.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CarePlanSection>> sectionHistory(int residentId, String domain) async {
    final res = await _api.get(
      '/care_plans.php',
      query: {'resident_id': residentId, 'domain': domain, 'history': '1'},
    );
    final list = (res['history'] as List? ?? []);
    return list.map((e) => CarePlanSection.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> create({
    required int residentId,
    required String domain,
    required String title,
    required String howToSupportMe,
    String? whatMattersToMe,
    String? goals,
    String? agreedWith,
    String? reviewDue,
  }) async {
    final res = await _api.post('/care_plans.php', {
      'resident_id': residentId,
      'domain': domain,
      'title': title,
      'how_to_support_me': howToSupportMe,
      'what_matters_to_me': whatMattersToMe,
      'goals': goals,
      'agreed_with': agreedWith,
      'review_due': reviewDue,
    });
    return res['id'] as int;
  }

  Future<int> review(int sectionId, Map<String, dynamic> changes) async {
    final res = await _api.put('/care_plans.php?id=$sectionId', changes);
    return res['id'] as int;
  }

  Future<void> delete(int sectionId) async {
    await _api.delete('/care_plans.php?id=$sectionId');
  }
}
