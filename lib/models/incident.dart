import 'package:intl/intl.dart';

/// An incident / accident report (falls, injuries, safeguarding, near-misses).
/// Designed to support CQC notification requirements and audit trails.
class Incident {
  final int id;
  final int residentId;
  final String? residentName;
  final String category; // fall, injury, medication_error, safeguarding, behaviour, near_miss, other
  final String severity; // minor, moderate, major, catastrophic
  final DateTime occurredAt;
  final DateTime reportedAt;
  final int reportedByStaffId;
  final String? reportedByName;
  final String? location;
  final String description;
  final String? immediateAction;
  final bool injurySustained;
  final String? injuryDetails;
  final bool witnessed;
  final String? witnesses;
  final bool familyNotified;
  final bool gpNotified;
  final bool cqcNotifiable; // RIDDOR / CQC notification flagged
  final bool safeguardingRaised;
  final List<String> photoUrls;
  final String status; // open, investigating, closed

  Incident({
    required this.id,
    required this.residentId,
    this.residentName,
    required this.category,
    this.severity = 'minor',
    required this.occurredAt,
    required this.reportedAt,
    required this.reportedByStaffId,
    this.reportedByName,
    this.location,
    required this.description,
    this.immediateAction,
    this.injurySustained = false,
    this.injuryDetails,
    this.witnessed = false,
    this.witnesses,
    this.familyNotified = false,
    this.gpNotified = false,
    this.cqcNotifiable = false,
    this.safeguardingRaised = false,
    this.photoUrls = const [],
    this.status = 'open',
  });

  String get occurredLabel =>
      DateFormat('d MMM yyyy, HH:mm').format(occurredAt.toLocal());

  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
        id: j['id'] as int,
        residentId: j['resident_id'] as int,
        residentName: j['resident_name'],
        category: j['category'] ?? 'other',
        severity: j['severity'] ?? 'minor',
        occurredAt: DateTime.parse(j['occurred_at']).toLocal(),
        reportedAt: DateTime.parse(j['reported_at']).toLocal(),
        reportedByStaffId: j['reported_by'] as int? ?? 0,
        reportedByName: j['reported_by_name'],
        location: j['location'],
        description: j['description'] ?? '',
        immediateAction: j['immediate_action'],
        injurySustained: j['injury'] == 1 || j['injury'] == true,
        injuryDetails: j['injury_details'],
        witnessed: j['witnessed'] == 1 || j['witnessed'] == true,
        witnesses: j['witnesses'],
        familyNotified: j['family_notified'] == 1 || j['family_notified'] == true,
        gpNotified: j['gp_notified'] == 1 || j['gp_notified'] == true,
        cqcNotifiable: j['cqc_notifiable'] == 1 || j['cqc_notifiable'] == true,
        safeguardingRaised:
            j['safeguarding'] == 1 || j['safeguarding'] == true,
        photoUrls: (j['photos'] is List)
            ? (j['photos'] as List).map((e) => e.toString()).toList()
            : [],
        status: j['status'] ?? 'open',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'resident_id': residentId,
        'category': category,
        'severity': severity,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'reported_at': reportedAt.toUtc().toIso8601String(),
        'reported_by': reportedByStaffId,
        'location': location,
        'description': description,
        'immediate_action': immediateAction,
        'injury': injurySustained ? 1 : 0,
        'injury_details': injuryDetails,
        'witnessed': witnessed ? 1 : 0,
        'witnesses': witnesses,
        'family_notified': familyNotified ? 1 : 0,
        'gp_notified': gpNotified ? 1 : 0,
        'cqc_notifiable': cqcNotifiable ? 1 : 0,
        'safeguarding': safeguardingRaised ? 1 : 0,
        'photos': photoUrls,
        'status': status,
      };

}
