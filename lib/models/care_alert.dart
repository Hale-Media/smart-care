/// A monitoring alert. Covers every "all scenarios" trigger source:
/// falls, call bells, wandering/elopement, bed/chair sensors, inactivity,
/// vitals deterioration, missed medication, and manual staff escalation.
enum AlertType {
  fall,
  callBell,
  wandering, // left a geofenced safe zone
  bedExit,
  chairExit,
  inactivity, // no movement detected for threshold period
  vitalsDeterioration,
  medicationMissed,
  manual,
  doorContact,
  panicButton;

  String get label {
    switch (this) {
      case AlertType.fall:
        return 'Fall detected';
      case AlertType.callBell:
        return 'Call bell';
      case AlertType.wandering:
        return 'Wandering / left safe zone';
      case AlertType.bedExit:
        return 'Bed exit';
      case AlertType.chairExit:
        return 'Chair exit';
      case AlertType.inactivity:
        return 'Inactivity';
      case AlertType.vitalsDeterioration:
        return 'Vitals deterioration';
      case AlertType.medicationMissed:
        return 'Medication missed';
      case AlertType.manual:
        return 'Manual escalation';
      case AlertType.doorContact:
        return 'Door / exit contact';
      case AlertType.panicButton:
        return 'Panic button';
    }
  }

  static AlertType fromString(String? v) => AlertType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => AlertType.manual,
      );
}

enum AlertStatus { active, acknowledged, resolved, escalated }

class CareAlert {
  final int id;
  final int? residentId;
  final String? residentName;
  final AlertType type;
  final String severity; // critical, high, medium, low, info
  final AlertStatus status;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final int? acknowledgedByStaffId;
  final DateTime? resolvedAt;
  final String? location; // room / zone label
  final double? lat;
  final double? lng;
  final String? message;
  final String? source; // sensor id, app, wearable

  CareAlert({
    required this.id,
    this.residentId,
    this.residentName,
    required this.type,
    this.severity = 'high',
    this.status = AlertStatus.active,
    required this.createdAt,
    this.acknowledgedAt,
    this.acknowledgedByStaffId,
    this.resolvedAt,
    this.location,
    this.lat,
    this.lng,
    this.message,
    this.source,
  });

  bool get isOpen =>
      status == AlertStatus.active || status == AlertStatus.escalated;

  Duration get age => DateTime.now().difference(createdAt);

  factory CareAlert.fromJson(Map<String, dynamic> j) => CareAlert(
        id: j['id'] as int,
        residentId: j['resident_id'],
        residentName: j['resident_name'],
        type: AlertType.fromString(j['type']),
        severity: j['severity'] ?? 'high',
        status: AlertStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => AlertStatus.active,
        ),
        createdAt: DateTime.parse(j['created_at']),
        acknowledgedAt: j['acknowledged_at'] != null
            ? DateTime.tryParse(j['acknowledged_at'])
            : null,
        acknowledgedByStaffId: j['acknowledged_by'],
        resolvedAt: j['resolved_at'] != null
            ? DateTime.tryParse(j['resolved_at'])
            : null,
        location: j['location'],
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        message: j['message'],
        source: j['source'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'resident_id': residentId,
        'resident_name': residentName,
        'type': type.name,
        'severity': severity,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'acknowledged_at': acknowledgedAt?.toIso8601String(),
        'acknowledged_by': acknowledgedByStaffId,
        'resolved_at': resolvedAt?.toIso8601String(),
        'location': location,
        'lat': lat,
        'lng': lng,
        'message': message,
        'source': source,
      };
}
