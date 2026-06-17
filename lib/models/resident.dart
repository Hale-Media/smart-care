import 'package:intl/intl.dart';

/// A care home resident being monitored.
class Resident {
  final int id;
  final String firstName;
  final String lastName;
  final DateTime? dob;
  final String? roomNumber;
  final String? photoUrl;
  final String? nhsNumber;
  final String
  careLevel; // residential, nursing, dementia, respite, palliative, home_care
  final String? address; // home address (used for home_care residents)
  final String callFrequency; // 'daily' | 'weekly'  (home_care only)
  final List<String> callTimes; // scheduled visit times e.g. ["09:00","14:00"]
  final List<String> conditions; // e.g. dementia, diabetes, COPD
  final List<String> allergies;
  final String mobility; // independent, walking_aid, wheelchair, bedbound
  final String fallRisk; // low, medium, high
  final String nutritionRisk; // low, medium, high
  final bool dnacpr; // Do Not Attempt CPR in place
  final List<String> medications; // required/prescribed medication names
  final List<String> monitoringMethods;
  final String
  monitoringConsent; // not_required, resident, representative, declined
  final String? consentRepresentative;
  final DateTime? consentRecordedAt;
  final DateTime? outcomeReviewDate;
  final String? gpName;
  final String? nextOfKin;
  final String? nextOfKinPhone;
  final bool active;
  final int? homeId;

  Resident({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.dob,
    this.roomNumber,
    this.photoUrl,
    this.nhsNumber,
    this.careLevel = 'residential',
    this.conditions = const [],
    this.allergies = const [],
    this.medications = const [],
    this.mobility = 'independent',
    this.fallRisk = 'low',
    this.nutritionRisk = 'low',
    this.dnacpr = false,
    this.monitoringMethods = const [],
    this.monitoringConsent = 'not_required',
    this.consentRepresentative,
    this.consentRecordedAt,
    this.outcomeReviewDate,
    this.address,
    this.callFrequency = 'daily',
    this.callTimes = const [],
    this.gpName,
    this.nextOfKin,
    this.nextOfKinPhone,
    this.active = true,
    this.homeId,
  });

  String get fullName => '$firstName $lastName';

  int? get age {
    if (dob == null) return null;
    final now = DateTime.now();
    var a = now.year - dob!.year;
    if (now.month < dob!.month ||
        (now.month == dob!.month && now.day < dob!.day)) {
      a--;
    }
    return a;
  }

  String get dobLabel =>
      dob == null ? '—' : DateFormat('d MMM yyyy').format(dob!);

  factory Resident.fromJson(Map<String, dynamic> j) => Resident(
    id: j['id'] as int,
    firstName: j['first_name'] ?? '',
    lastName: j['last_name'] ?? '',
    dob: j['dob'] != null ? DateTime.tryParse(j['dob']) : null,
    roomNumber: j['room_number'],
    photoUrl: j['photo_url'],
    nhsNumber: j['nhs_number'],
    careLevel: j['care_level'] ?? 'residential',
    address: j['address'],
    callFrequency: j['call_frequency'] ?? 'daily',
    callTimes: _list(j['call_times']),
    conditions: _list(j['conditions']),
    allergies: _list(j['allergies']),
    medications: _list(j['medications']),
    monitoringMethods: _list(j['monitoring_methods']),
    mobility: j['mobility'] ?? 'independent',
    fallRisk: j['fall_risk'] ?? 'low',
    nutritionRisk: j['nutrition_risk'] ?? 'low',
    dnacpr: j['dnacpr'] == 1 || j['dnacpr'] == true,
    monitoringConsent: j['monitoring_consent'] ?? 'not_required',
    consentRepresentative: j['consent_representative'],
    consentRecordedAt: j['consent_recorded_at'] != null
        ? DateTime.tryParse(j['consent_recorded_at'])
        : null,
    outcomeReviewDate: j['outcome_review_date'] != null
        ? DateTime.tryParse(j['outcome_review_date'])
        : null,
    gpName: j['gp_name'],
    nextOfKin: j['next_of_kin'],
    nextOfKinPhone: j['next_of_kin_phone'],
    active: j['active'] == null
        ? true
        : (j['active'] == 1 || j['active'] == true),
    homeId: j['home_id'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'dob': dob == null ? null : DateFormat('yyyy-MM-dd').format(dob!),
    'room_number': roomNumber,
    'photo_url': photoUrl,
    'nhs_number': nhsNumber,
    'care_level': careLevel,
    if (address != null) 'address': address,
    'call_frequency': callFrequency,
    'call_times': callTimes,
    'conditions': conditions,
    'allergies': allergies,
    'medications': medications,
    'monitoring_methods': monitoringMethods,
    'mobility': mobility,
    'fall_risk': fallRisk,
    'nutrition_risk': nutritionRisk,
    'dnacpr': dnacpr ? 1 : 0,
    'monitoring_consent': monitoringConsent,
    'consent_representative': consentRepresentative,
    'consent_recorded_at': consentRecordedAt == null
        ? null
        : DateFormat('yyyy-MM-dd').format(consentRecordedAt!),
    'outcome_review_date': outcomeReviewDate == null
        ? null
        : DateFormat('yyyy-MM-dd').format(outcomeReviewDate!),
    'gp_name': gpName,
    'next_of_kin': nextOfKin,
    'next_of_kin_phone': nextOfKinPhone,
    'active': active ? 1 : 0,
    if (homeId != null) 'home_id': homeId,
  };

  static List<String> _list(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) {
      return v.split(',').map((e) => e.trim()).toList();
    }
    return [];
  }
}
