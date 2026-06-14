import '../config/app_config.dart';

/// An authenticated staff member.
class StaffUser {
  final int id;
  final String name;
  final String email;
  final StaffRole role;
  final int companyId; // tenant the user belongs to
  final int homeId;
  final bool canSwitchHomes; // owner-controlled permission
  final String? homeName; // populated when listing staff
  final String? pin;
  final bool onShift;
  final bool active;

  StaffUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.companyId,
    required this.homeId,
    this.canSwitchHomes = false,
    this.homeName,
    this.pin,
    this.onShift = false,
    this.active = true,
  });

  /// Whether this user may switch the active home (admins always can).
  bool get maySwitchHomes => role == StaffRole.admin || canSwitchHomes;

  factory StaffUser.fromJson(Map<String, dynamic> j) => StaffUser(
        id: j['id'] as int,
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        role: StaffRole.fromString(j['role']),
        companyId: j['company_id'] as int? ?? 0,
        homeId: j['home_id'] as int? ?? 0,
        canSwitchHomes:
            j['can_switch_homes'] == 1 || j['can_switch_homes'] == true,
        homeName: j['home_name'],
        pin: j['pin'],
        onShift: j['on_shift'] == 1 || j['on_shift'] == true,
        active: j['active'] == null
            ? true
            : (j['active'] == 1 || j['active'] == true),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'company_id': companyId,
        'home_id': homeId,
        'can_switch_homes': canSwitchHomes ? 1 : 0,
        'home_name': homeName,
        'pin': pin,
        'on_shift': onShift ? 1 : 0,
        'active': active ? 1 : 0,
      };
}
