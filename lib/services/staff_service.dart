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
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'role': role.name,
      'home_id': homeId,
    };
    if (pin != null && pin.isNotEmpty) body['pin'] = pin;
    final res = await _api.post('/staff/create.php', body);
    return StaffUser.fromJson(res['user'] as Map<String, dynamic>);
  }

  Future<void> updateRole(int staffId, StaffRole role) =>
      _api.post('/staff/update.php', {'id': staffId, 'role': role.name});

  Future<void> setCanSwitchHomes(int staffId, bool canSwitch) =>
      _api.post('/staff/update.php', {
        'id': staffId,
        'can_switch_homes': canSwitch ? 1 : 0,
      });

  Future<void> setActive(int staffId, bool active) =>
      _api.post('/staff/update.php', {'id': staffId, 'active': active ? 1 : 0});

  Future<void> delete(int staffId) =>
      _api.post('/staff/delete.php', {'id': staffId});
}
