import 'package:intl/intl.dart';

/// A prescribed medication on a resident's MAR (Medication Administration Record).
class Medication {
  final int id;
  final int residentId;
  final String name;
  final String dose; // e.g. "5mg"
  final String route; // oral, topical, subcutaneous, PRN
  final String frequency; // human readable, e.g. "Twice daily"
  final List<String> times; // ["08:00", "20:00"]
  final bool prn; // 'as required'
  final String? prnReason;
  final bool controlledDrug; // CD register applies
  final DateTime? startDate;
  final DateTime? endDate;
  final String? instructions;
  final bool active;
  final DateTime? lastAdministeredAt;
  final String? lastAdministeredByName;

  Medication({
    required this.id,
    required this.residentId,
    required this.name,
    required this.dose,
    this.route = 'oral',
    this.frequency = '',
    this.times = const [],
    this.prn = false,
    this.prnReason,
    this.controlledDrug = false,
    this.startDate,
    this.endDate,
    this.instructions,
    this.active = true,
    this.lastAdministeredAt,
    this.lastAdministeredByName,
  });

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] as int,
        residentId: j['resident_id'] as int,
        name: j['name'] ?? '',
        dose: j['dose'] ?? '',
        route: j['route'] ?? 'oral',
        frequency: j['frequency'] ?? '',
        times: (j['times'] is List)
            ? (j['times'] as List).map((e) => e.toString()).toList()
            : (j['times']?.toString().split(',') ?? []),
        prn: j['prn'] == 1 || j['prn'] == true,
        prnReason: j['prn_reason'],
        controlledDrug: j['controlled_drug'] == 1 || j['controlled_drug'] == true,
        startDate: j['start_date'] != null ? DateTime.tryParse(j['start_date']) : null,
        endDate: j['end_date'] != null ? DateTime.tryParse(j['end_date']) : null,
        instructions: j['instructions'],
        active: j['active'] == null ? true : (j['active'] == 1 || j['active'] == true),
        lastAdministeredAt: j['last_administered_at'] != null
            ? DateTime.tryParse('${j['last_administered_at']}Z')?.toLocal()
            : null,
        lastAdministeredByName: j['last_administered_by_name'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'resident_id': residentId,
        'name': name,
        'dose': dose,
        'route': route,
        'frequency': frequency,
        'times': times,
        'prn': prn ? 1 : 0,
        'prn_reason': prnReason,
        'controlled_drug': controlledDrug ? 1 : 0,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'instructions': instructions,
        'active': active ? 1 : 0,
      };
}

/// A single administration event against a medication (the MAR entry).
enum MarOutcome { given, refused, omitted, unavailable, asleep, hospital }

class MarEntry {
  final int id;
  final int medicationId;
  final int residentId;
  final DateTime scheduledFor;
  final DateTime? administeredAt;
  final int? administeredByStaffId;
  final String? administeredByName;
  final MarOutcome outcome;
  final String? witnessStaffName; // required for controlled drugs
  final String? notes;
  final String? medicationName;

  MarEntry({
    required this.id,
    required this.medicationId,
    required this.residentId,
    required this.scheduledFor,
    this.administeredAt,
    this.administeredByStaffId,
    this.administeredByName,
    this.outcome = MarOutcome.given,
    this.witnessStaffName,
    this.notes,
    this.medicationName,
  });

  String get scheduledLabel => DateFormat('HH:mm').format(scheduledFor);

  factory MarEntry.fromJson(Map<String, dynamic> j) => MarEntry(
        id: j['id'] as int,
        medicationId: j['medication_id'] as int,
        residentId: j['resident_id'] as int,
        scheduledFor: DateTime.parse('${j['scheduled_for']}Z').toLocal(),
        administeredAt: j['administered_at'] != null
            ? DateTime.tryParse('${j['administered_at']}Z')?.toLocal()
            : null,
        administeredByStaffId: j['administered_by'],
        administeredByName: j['administered_by_name'],
        outcome: MarOutcome.values.firstWhere(
          (e) => e.name == j['outcome'],
          orElse: () => MarOutcome.given,
        ),
        witnessStaffName: j['witness'],
        notes: j['notes'],
        medicationName: j['medication_name'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'medication_id': medicationId,
        'resident_id': residentId,
        'scheduled_for': scheduledFor.toIso8601String(),
        'administered_at': administeredAt?.toIso8601String(),
        'administered_by': administeredByStaffId,
        'administered_by_name': administeredByName,
        'outcome': outcome.name,
        'witness': witnessStaffName,
        'notes': notes,
      };
}
