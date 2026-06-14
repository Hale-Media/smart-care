import 'package:intl/intl.dart';

class HandoverNote {
  final int id;
  final String shift; // am, pm, night
  final String content;
  final int? staffId;
  final String? staffName;
  final DateTime createdAt;
  final int? homeId;

  HandoverNote({
    required this.id,
    required this.shift,
    required this.content,
    this.staffId,
    this.staffName,
    required this.createdAt,
    this.homeId,
  });

  String get shiftLabel => switch (shift) {
        'am' => 'AM shift',
        'pm' => 'PM shift',
        'night' => 'Night shift',
        _ => shift,
      };

  String get createdLabel =>
      DateFormat('EEE d MMM, HH:mm').format(createdAt.toLocal());

  factory HandoverNote.fromJson(Map<String, dynamic> j) => HandoverNote(
        id: j['id'] as int,
        shift: j['shift'] ?? 'am',
        content: j['content'] ?? '',
        staffId: j['staff_id'] as int?,
        staffName: j['staff_name'],
        createdAt: DateTime.parse(j['created_at']),
        homeId: j['home_id'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'shift': shift,
        'content': content,
        if (staffId != null) 'staff_id': staffId,
        if (homeId != null) 'home_id': homeId,
      };
}
