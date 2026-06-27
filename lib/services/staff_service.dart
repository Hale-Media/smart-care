import '../config/app_config.dart';
import '../models/staff_user.dart';
import 'api_client.dart';

/// Company staff management (managers/admins).
class StaffService {
  final _api = ApiClient.instance;

  Future<List<StaffUser>> list() async {
    final res = await _api.get('/staff/list.php');
    final items = (res['staff'] as List? ?? []);
    return items.map((e) => StaffUser.fromJson(e)).toList();
  }

  Future<StaffUser> create({
    required String name,
    required String email,
    required String password,
    required StaffRole role,
    required int homeId,
    String? pin,
    String? monitoringCompetency,
    String? supervisionNotes,
    DateTime? competencyReviewDate,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'role': role.name,
      'home_id': homeId,
      if (monitoringCompetency != null && monitoringCompetency.isNotEmpty)
        'monitoring_competency': monitoringCompetency,
      if (supervisionNotes != null && supervisionNotes.isNotEmpty)
        'supervision_notes': supervisionNotes,
      if (competencyReviewDate != null)
        'competency_review_date': competencyReviewDate
            .toIso8601String()
            .split('T')
            .first,
    };
    if (pin != null && pin.isNotEmpty) body['pin'] = pin;
    final res = await _api.post('/staff/create.php', body);
    return StaffUser.fromJson(res['user'] as Map<String, dynamic>);
  }

  Future<void> reassignHome(int staffId, int homeId) =>
      _api.post('/staff/update.php', {'id': staffId, 'home_id': homeId});

  Future<void> updateRole(int staffId, StaffRole role) =>
      _api.post('/staff/update.php', {'id': staffId, 'role': role.name});

  Future<void> setCanSwitchHomes(int staffId, bool canSwitch) => _api.post(
    '/staff/update.php',
    {'id': staffId, 'can_switch_homes': canSwitch ? 1 : 0},
  );

  Future<void> setActive(int staffId, bool active) =>
      _api.post('/staff/update.php', {'id': staffId, 'active': active ? 1 : 0});

  Future<void> updateCompliance({
    required int staffId,
    String? monitoringCompetency,
    String? supervisionNotes,
    DateTime? competencyReviewDate,
  }) => _api.post('/staff/update.php', {
    'id': staffId,
    'monitoring_competency': monitoringCompetency,
    'supervision_notes': supervisionNotes,
    'competency_review_date': competencyReviewDate
        ?.toIso8601String()
        .split('T')
        .first,
  });

  Future<void> delete(int staffId) =>
      _api.post('/staff/delete.php', {'id': staffId});
}
