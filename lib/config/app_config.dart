/// Central app configuration and constants.
class AppConfig {
  AppConfig._();

  static const String appName = 'Smart Care';
  static const String appVersion = '1.0.0';

  /// Base URL for the PHP/MySQL backend API.
  /// Override per environment (dev/staging/prod).
  static const String apiBaseUrl = 'https://smartcareuk.uk/backend/api';

  /// Network timeout for HTTP requests.
  static const Duration httpTimeout = Duration(seconds: 20);

  /// How often the dashboard auto-refreshes live data.
  static const Duration liveRefreshInterval = Duration(seconds: 30);

  /// SharedPreferences / secure storage keys.
  static const String kAuthToken = 'auth_token';
  static const String kRefreshToken = 'refresh_token';
  static const String kCurrentUser = 'current_user';
  static const String kHomeId = 'home_id';

  /// Map defaults (UK centre).
  static const double defaultLat = 53.4084; // Liverpool
  static const double defaultLng = -2.9916;
  static const double defaultZoom = 15.0;
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}

/// Staff roles used for access control across the app.
enum StaffRole {
  carer,
  seniorCarer,
  nurse,
  manager,
  admin;

  String get label {
    switch (this) {
      case StaffRole.carer:
        return 'Carer';
      case StaffRole.seniorCarer:
        return 'Senior Carer';
      case StaffRole.nurse:
        return 'Nurse';
      case StaffRole.manager:
        return 'Manager';
      case StaffRole.admin:
        return 'Administrator';
    }
  }

  static StaffRole fromString(String? v) {
    return StaffRole.values.firstWhere(
      (e) => e.name == v,
      orElse: () => StaffRole.carer,
    );
  }

  /// Whether this role can edit care plans, sign off MAR, manage staff.
  bool get canManage => this == StaffRole.manager || this == StaffRole.admin;
  bool get canAdministerMeds => this == StaffRole.nurse || canManage;
}
