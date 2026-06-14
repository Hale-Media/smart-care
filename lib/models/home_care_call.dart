import 'package:intl/intl.dart';

class HomeCareCall {
  final int id;
  final int residentId;
  final String residentName;
  final String scheduledTime; // "09:00"
  final DateTime date;
  final bool confirmed;
  final DateTime? confirmedAt;
  final String? confirmedByName;
  final String? notes;

  const HomeCareCall({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.scheduledTime,
    required this.date,
    this.confirmed = false,
    this.confirmedAt,
    this.confirmedByName,
    this.notes,
  });

  String get dateLabel => DateFormat('d MMM yyyy').format(date);

  /// DateTime combining date + scheduledTime for comparison.
  DateTime get scheduledDateTime {
    final parts = scheduledTime.split(':');
    return DateTime(
        date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  factory HomeCareCall.fromJson(Map<String, dynamic> j) => HomeCareCall(
        id: j['id'] as int,
        residentId: j['resident_id'] as int,
        residentName: j['resident_name'] ?? '',
        scheduledTime: j['scheduled_time'] ?? '',
        date: DateTime.parse(j['scheduled_date']),
        confirmed: j['confirmed'] == 1 || j['confirmed'] == true,
        confirmedAt: j['confirmed_at'] != null
            ? DateTime.tryParse(j['confirmed_at'])
            : null,
        confirmedByName: j['confirmed_by_name'],
        notes: j['notes'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'resident_id': residentId,
        'scheduled_time': scheduledTime,
        'scheduled_date': DateFormat('yyyy-MM-dd').format(date),
        if (notes != null) 'notes': notes,
      };
}
