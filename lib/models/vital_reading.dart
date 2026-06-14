/// A set of recorded vital signs for a resident.
/// Includes NEWS2 (National Early Warning Score 2) calculation, widely used
/// across UK care settings to flag deterioration.
class VitalReading {
  final int id;
  final int residentId;
  final DateTime recordedAt;
  final int recordedByStaffId;

  final int? respiratoryRate; // breaths/min
  final int? spo2; // %
  final bool onOxygen;
  final double? temperature; // °C
  final int? systolicBp; // mmHg
  final int? heartRate; // bpm
  final String consciousness; // A (alert), V, P, U (ACVPU)
  final double? bloodGlucose; // mmol/L (optional, diabetic residents)
  final String? notes;

  VitalReading({
    required this.id,
    required this.residentId,
    required this.recordedAt,
    required this.recordedByStaffId,
    this.respiratoryRate,
    this.spo2,
    this.onOxygen = false,
    this.temperature,
    this.systolicBp,
    this.heartRate,
    this.consciousness = 'A',
    this.bloodGlucose,
    this.notes,
  });

  /// NEWS2 aggregate score. Higher = more concern.
  int get news2Score {
    var score = 0;

    final rr = respiratoryRate;
    if (rr != null) {
      if (rr <= 8) {
        score += 3;
      } else if (rr <= 11) {
        score += 1;
      } else if (rr <= 20) {
        score += 0;
      } else if (rr <= 24) {
        score += 2;
      } else {
        score += 3;
      }
    }

    final s = spo2;
    if (s != null) {
      if (s <= 91) {
        score += 3;
      } else if (s <= 93) {
        score += 2;
      } else if (s <= 95) {
        score += 1;
      }
    }
    if (onOxygen) score += 2;

    final t = temperature;
    if (t != null) {
      if (t <= 35.0) {
        score += 3;
      } else if (t <= 36.0) {
        score += 1;
      } else if (t <= 38.0) {
        score += 0;
      } else if (t <= 39.0) {
        score += 1;
      } else {
        score += 2;
      }
    }

    final bp = systolicBp;
    if (bp != null) {
      if (bp <= 90) {
        score += 3;
      } else if (bp <= 100) {
        score += 2;
      } else if (bp <= 110) {
        score += 1;
      } else if (bp >= 220) {
        score += 3;
      }
    }

    final hr = heartRate;
    if (hr != null) {
      if (hr <= 40) {
        score += 3;
      } else if (hr <= 50) {
        score += 1;
      } else if (hr <= 90) {
        score += 0;
      } else if (hr <= 110) {
        score += 1;
      } else if (hr <= 130) {
        score += 2;
      } else {
        score += 3;
      }
    }

    if (consciousness.toUpperCase() != 'A') score += 3;

    return score;
  }

  /// Clinical risk band derived from NEWS2.
  String get riskBand {
    final n = news2Score;
    if (n >= 7) return 'high';
    if (n >= 5) return 'medium';
    if (n >= 1) return 'low';
    return 'normal';
  }

  factory VitalReading.fromJson(Map<String, dynamic> j) => VitalReading(
        id: j['id'] as int,
        residentId: j['resident_id'] as int,
        recordedAt: DateTime.parse(j['recorded_at']),
        recordedByStaffId: j['recorded_by'] as int? ?? 0,
        respiratoryRate: j['respiratory_rate'],
        spo2: j['spo2'],
        onOxygen: j['on_oxygen'] == 1 || j['on_oxygen'] == true,
        temperature: (j['temperature'] as num?)?.toDouble(),
        systolicBp: j['systolic_bp'],
        heartRate: j['heart_rate'],
        consciousness: j['consciousness'] ?? 'A',
        bloodGlucose: (j['blood_glucose'] as num?)?.toDouble(),
        notes: j['notes'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'resident_id': residentId,
        'recorded_at': recordedAt.toIso8601String(),
        'recorded_by': recordedByStaffId,
        'respiratory_rate': respiratoryRate,
        'spo2': spo2,
        'on_oxygen': onOxygen ? 1 : 0,
        'temperature': temperature,
        'systolic_bp': systolicBp,
        'heart_rate': heartRate,
        'consciousness': consciousness,
        'blood_glucose': bloodGlucose,
        'notes': notes,
      };
}
