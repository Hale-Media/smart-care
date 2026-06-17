import '../config/app_config.dart';

/// Per-staff competency statistics returned by /staff/competency/summary.php.
class StaffCompetencySummary {
  final int id;
  final String name;
  final String role;
  final int total;
  final int valid;
  final int expired;
  final int expiring;

  const StaffCompetencySummary({
    required this.id,
    required this.name,
    required this.role,
    required this.total,
    required this.valid,
    required this.expired,
    required this.expiring,
  });

  bool get hasNoRecords => total == 0;
  bool get hasExpired => expired > 0;
  bool get hasExpiring => expiring > 0;
  bool get allGood => total > 0 && expired == 0 && valid > 0;

  StaffRole get staffRole =>
      StaffRole.values.firstWhere((e) => e.name == role, orElse: () => StaffRole.carer);

  factory StaffCompetencySummary.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse('$v') ?? 0);
    return StaffCompetencySummary(
      id: asInt(j['id']),
      name: j['name'] ?? '',
      role: j['role'] ?? '',
      total: asInt(j['total']),
      valid: asInt(j['valid']),
      expired: asInt(j['expired']),
      expiring: asInt(j['expiring']),
    );
  }
}
