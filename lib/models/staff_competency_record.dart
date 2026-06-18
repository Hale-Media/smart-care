import 'package:intl/intl.dart';

/// A single competency assessment record for a staff member.
class StaffCompetencyRecord {
  final int id;
  final int staffId;
  final String competency;
  final DateTime assessedDate;
  final DateTime? expiryDate;
  final String assessedBy;
  final String outcome; // passed, failed, pending
  final String? notes;
  final DateTime createdAt;

  const StaffCompetencyRecord({
    required this.id,
    required this.staffId,
    required this.competency,
    required this.assessedDate,
    this.expiryDate,
    required this.assessedBy,
    this.outcome = 'passed',
    this.notes,
    required this.createdAt,
  });

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  bool get expiresSoon {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));
  }

  String get assessedDateLabel => DateFormat('d MMM yyyy').format(assessedDate);

  String get expiryDateLabel =>
      expiryDate == null ? '—' : DateFormat('d MMM yyyy').format(expiryDate!);

  factory StaffCompetencyRecord.fromJson(Map<String, dynamic> j) =>
      StaffCompetencyRecord(
        id: j['id'] as int,
        staffId: j['staff_id'] as int,
        competency: j['competency'] ?? '',
        assessedDate: DateTime.parse(j['assessed_date']),
        expiryDate: j['expiry_date'] != null
            ? DateTime.tryParse(j['expiry_date'])
            : null,
        assessedBy: j['assessed_by'] ?? '',
        outcome: j['outcome'] ?? 'passed',
        notes: j['notes'],
        createdAt: j['created_at'] != null
            ? DateTime.tryParse('${j['created_at']}Z')?.toLocal() ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
    'staff_id': staffId,
    'competency': competency,
    'assessed_date': DateFormat('yyyy-MM-dd').format(assessedDate),
    if (expiryDate != null)
      'expiry_date': DateFormat('yyyy-MM-dd').format(expiryDate!),
    'assessed_by': assessedBy,
    'outcome': outcome,
    if (notes != null) 'notes': notes,
  };
}
