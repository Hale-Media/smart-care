import 'package:intl/intl.dart';

/// A welfare/comfort check completed during a round (hourly checks, night checks,
/// repositioning for pressure-area care, continence, food & fluid).
class CareRound {
  final int id;
  final int residentId;
  final String? residentName;
  final DateTime dueAt;
  final DateTime? completedAt;
  final int? completedByStaffId;
  final String? completedByName;
  final String type; // welfare, repositioning, continence, fluid, food, night
  final String? position; // for repositioning: left, right, back
  final String? observation; // settled, asleep, awake, distressed
  final bool skipped;
  final String? notes;
  final double? intakeAmount; // ml for fluid, grams for food
  final String? intakeUnit;   // 'ml', 'g', or '%'

  CareRound({
    required this.id,
    required this.residentId,
    this.residentName,
    required this.dueAt,
    this.completedAt,
    this.completedByStaffId,
    this.completedByName,
    this.type = 'welfare',
    this.position,
    this.observation,
    this.skipped = false,
    this.notes,
    this.intakeAmount,
    this.intakeUnit,
  });

  bool get isOverdue =>
      completedAt == null && DateTime.now().isAfter(dueAt) && !skipped;
  bool get isDone => completedAt != null;
  String get dueLabel => DateFormat('HH:mm').format(dueAt);

  factory CareRound.fromJson(Map<String, dynamic> j) => CareRound(
        id: j['id'] as int,
        residentId: j['resident_id'] as int,
        residentName: j['resident_name'],
        dueAt: DateTime.parse('${j['due_at']}Z').toLocal(),
        completedAt: j['completed_at'] != null
            ? DateTime.tryParse('${j['completed_at']}Z')?.toLocal()
            : null,
        completedByStaffId: j['completed_by'],
        completedByName: j['completed_by_name'],
        type: j['type'] ?? 'welfare',
        position: j['position'],
        observation: j['observation'],
        skipped: j['skipped'] == 1 || j['skipped'] == true,
        notes: j['notes'],
        intakeAmount: (j['intake_amount'] as num?)?.toDouble(),
        intakeUnit: j['intake_unit'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'resident_id': residentId,
        'due_at': dueAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'completed_by': completedByStaffId,
        'type': type,
        'position': position,
        'observation': observation,
        'skipped': skipped ? 1 : 0,
        'notes': notes,
        if (intakeAmount != null) 'intake_amount': intakeAmount,
        if (intakeUnit != null) 'intake_unit': intakeUnit,
      };
}
