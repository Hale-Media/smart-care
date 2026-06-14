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
  final String careLevel; // residential, nursing, dementia, respite, palliative, home_care
  final String? address; // home address (used for home_care residents)
  final String callFrequency; // 'daily' | 'weekly'  (home_care only)
  final List<String> callTimes; // scheduled visit times e.g. ["09:00","14:00"]
  final List<String> conditions; // e.g. dementia, diabetes, COPD
  final List<String> allergies;
  final String mobility; // independent, walking_aid, wheelchair, bedbound
  final String fallRisk; // low, medium, high
  final bool dnacpr; // Do Not Attempt CPR in place
  final List<String> medications; // required/prescribed medication names
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
    this.dnacpr = false,
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
        mobility: j['mobility'] ?? 'independent',
        fallRisk: j['fall_risk'] ?? 'low',
        dnacpr: j['dnacpr'] == 1 || j['dnacpr'] == true,
        gpName: j['gp_name'],
        nextOfKin: j['next_of_kin'],
        nextOfKinPhone: j['next_of_kin_phone'],
        active: j['active'] == null ? true : (j['active'] == 1 || j['active'] == true),
        homeId: j['home_id'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'dob': dob?.toIso8601String(),
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
        'mobility': mobility,
        'fall_risk': fallRisk,
        'dnacpr': dnacpr ? 1 : 0,
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
