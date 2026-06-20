import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../config/app_config.dart';
import '../models/home.dart';
import '../models/staff_user.dart';
import 'api_client.dart';

/// Handles login (email/password and quick-PIN), token persistence,
/// session restore, and logout.
class AuthService {
  final _api = ApiClient.instance;
  final _storage = const FlutterSecureStorage();

  Future<StaffUser> login(String email, String password) async {
    final res = await _api.post('/auth/login.php', {
      'email': email,
      'password': password,
    }, auth: false);
    return _persistSession(res);
  }

  /// Quick PIN sign-in for shared ward devices.
  Future<StaffUser> loginWithPin(String pin) async {
    final res = await _api.post('/auth/pin_login.php', {
      'pin': pin,
    }, auth: false);
    return _persistSession(res);
  }

  Future<StaffUser> _persistSession(dynamic res) async {
    final token = res['token'] as String;
    await _api.setToken(token);
    if (res['refresh_token'] != null) {
      await _storage.write(
        key: AppConfig.kRefreshToken,
        value: res['refresh_token'],
      );
    }
    final user = StaffUser.fromJson(res['user']);
    await _storage.write(
      key: AppConfig.kCurrentUser,
      value: jsonEncode(user.toJson()),
    );
    await _storage.write(key: AppConfig.kHomeId, value: '${user.homeId}');
    return user;
  }

  /// Restore an existing session on app launch, if the token is still valid.
  Future<StaffUser?> restore() async {
    final token = await _storage.read(key: AppConfig.kAuthToken);
    if (token == null || JwtDecoder.isExpired(token)) {
      await logout();
      return null;
    }
    final raw = await _storage.read(key: AppConfig.kCurrentUser);
    if (raw == null) return null;
    return StaffUser.fromJson(jsonDecode(raw));
  }

  Future<Home> activeHome() async {
    final res = await _api.get('/homes/active.php') as Map<String, dynamic>;
    return Home.fromJson(res['home'] as Map<String, dynamic>);
  }

  Future<Home> switchHome(int homeId) async {
    final res = await _api.post('/homes/switch.php', {'home_id': homeId}) as Map<String, dynamic>;
    await _api.setToken(res['token'] as String);
    await _storage.write(key: AppConfig.kHomeId, value: '$homeId');
    return Home.fromJson(res['home'] as Map<String, dynamic>);
  }

  Future<StaffUser> register({
    required String companyName,
    required String adminName,
    required String adminEmail,
    required String password,
    String? homeName,
  }) async {
    final res = await _api.post('/auth/register.php', {
      'company_name': companyName,
      'admin_name': adminName,
      'admin_email': adminEmail,
      'password': password,
      'home_name': ?homeName,
    }, auth: false);
    return _persistSession(res);
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout.php', {});
    } catch (_) {
      // Best-effort — always clear local state even if server is unreachable.
    }
    await _api.setToken(null);
    await _storage.delete(key: AppConfig.kRefreshToken);
    await _storage.delete(key: AppConfig.kCurrentUser);
  }
}
