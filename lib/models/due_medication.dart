import 'package:intl/intl.dart';

/// A scheduled medication slot for today, with its MAR administration status.
class DueMedication {
  final int medicationId;
  final int residentId;
  final String residentName;
  final String name;
  final String dose;
  final bool controlledDrug;
  final DateTime scheduledFor;
  final bool given;
  final int? marEntryId;
  final String? outcome;
  final String? givenByName;
  final DateTime? givenAt;

  const DueMedication({
    required this.medicationId,
    required this.residentId,
    required this.residentName,
    required this.name,
    required this.dose,
    required this.controlledDrug,
    required this.scheduledFor,
    required this.given,
    this.marEntryId,
    this.outcome,
    this.givenByName,
    this.givenAt,
  });

  String get timeLabel => DateFormat('HH:mm').format(scheduledFor);

  bool get isOverdue => !given && scheduledFor.isBefore(DateTime.now());

  factory DueMedication.fromJson(Map<String, dynamic> j) => DueMedication(
        medicationId: j['medication_id'] as int,
        residentId: j['resident_id'] as int,
        residentName: j['resident_name'] ?? '',
        name: j['name'] ?? '',
        dose: j['dose'] ?? '',
        controlledDrug:
            j['controlled_drug'] == true || j['controlled_drug'] == 1,
        scheduledFor: DateTime.parse((j['scheduled_for'] as String).replaceFirst(' ', 'T')),
        given: j['given'] == true || j['given'] == 1,
        marEntryId: j['mar_entry_id'] as int?,
        outcome: j['outcome'] as String?,
        givenByName: j['given_by_name'] as String?,
        givenAt: j['given_at'] != null
            ? DateTime.tryParse('${j['given_at']}Z')?.toLocal()
            : null,
      );
}
