import 'package:flutter/foundation.dart';
import '../models/staff_user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  AuthStatus _status = AuthStatus.unknown;
  StaffUser? _user;
  String? _error;
  bool _busy = false;
  int? _activeHomeId;
  String? _activeHomeName;

  AuthStatus get status => _status;
  StaffUser? get user => _user;
  String? get error => _error;
  bool get busy => _busy;

  /// The home the app is currently operating against (may differ from the
  /// user's default home if they've switched).
  int? get activeHomeId => _activeHomeId;
  String? get activeHomeName => _activeHomeName;

  /// Whether the signed-in user is permitted to switch the active home.
  bool get canSwitchHomes => _user?.maySwitchHomes ?? false;

  Future<void> bootstrap() async {
    _user = await _service.restore();
    if (_user != null) {
      try {
        final ah = await _service.activeHome();
        _activeHomeId = ah.id;
        _activeHomeName = ah.name;
      } catch (_) {
        _activeHomeId = _user!.homeId;
        _activeHomeName = _user!.homeName;
      }
    }
    _status = _user != null
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Switch the active home (company managers/admins with more than one home).
  Future<bool> switchHome(int homeId) async {
    try {
      final h = await _service.switchHome(homeId);
      _activeHomeId = h.id;
      _activeHomeName = h.name;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    return _run(() => _service.login(email, password));
  }

  Future<bool> loginWithPin(String pin) async {
    return _run(() => _service.loginWithPin(pin));
  }

  Future<bool> register({
    required String companyName,
    required String adminName,
    required String adminEmail,
    required String password,
    String? homeName,
  }) async {
    return _run(
      () => _service.register(
        companyName: companyName,
        adminName: adminName,
        adminEmail: adminEmail,
        password: password,
        homeName: homeName,
      ),
    );
  }

  Future<bool> _run(Future<StaffUser> Function() fn) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await fn();
      _status = AuthStatus.authenticated;
      _activeHomeId = _user?.homeId;
      _activeHomeName = _user?.homeName;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
