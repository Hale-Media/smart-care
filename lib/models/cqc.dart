/// CQC provider/location data returned by our backend proxy.
class CqcLocation {
  final String locationId;
  final String? name;
  final String? registrationStatus;
  final String? postalCode;
  final String? overallRating; // Outstanding / Good / Requires improvement / Inadequate / null
  final String? ratingDate;

  CqcLocation({
    required this.locationId,
    this.name,
    this.registrationStatus,
    this.postalCode,
    this.overallRating,
    this.ratingDate,
  });

  factory CqcLocation.fromJson(Map<String, dynamic> j) => CqcLocation(
        locationId: j['locationId'] ?? '',
        name: j['name'],
        registrationStatus: j['registrationStatus'],
        postalCode: j['postalCode'],
        overallRating: j['overallRating'],
        ratingDate: j['ratingDate'],
      );
}

class CqcProvider {
  final String providerId;
  final String? name;
  final String? registrationStatus;
  final String? type;
  final String? postalCode;
  final int locationCount;

  CqcProvider({
    required this.providerId,
    this.name,
    this.registrationStatus,
    this.type,
    this.postalCode,
    this.locationCount = 0,
  });

  factory CqcProvider.fromJson(Map<String, dynamic> j) => CqcProvider(
        providerId: j['providerId'] ?? '',
        name: j['name'],
        registrationStatus: j['registrationStatus'],
        type: j['type'],
        postalCode: j['postalCode'],
        locationCount: (j['locationCount'] as num?)?.toInt() ?? 0,
      );
}

class CqcVerification {
  final bool registered;
  final CqcProvider? provider;
  final List<CqcLocation> locations;
  CqcVerification(
      {required this.registered, this.provider, this.locations = const []});

  factory CqcVerification.fromJson(Map<String, dynamic> j) => CqcVerification(
        registered: j['registered'] == true,
        provider: j['provider'] != null
            ? CqcProvider.fromJson(j['provider'])
            : null,
        locations: ((j['locations'] as List?) ?? [])
            .map((e) => CqcLocation.fromJson(e))
            .toList(),
      );
}

/// A home's linked CQC rating (cached server-side).
class HomeCqc {
  final bool linked;
  final String? locationId;
  final String? rating;
  final String? ratingDate;
  final String? homeName;
  HomeCqc(
      {required this.linked,
      this.locationId,
      this.rating,
      this.ratingDate,
      this.homeName});

  factory HomeCqc.fromJson(Map<String, dynamic> j) => HomeCqc(
        linked: j['linked'] == true,
        locationId: j['locationId'],
        rating: j['rating'],
        ratingDate: j['ratingDate'],
        homeName: j['homeName'],
      );
}

/// Map a CQC rating to the app's StatusPill severity bands.
String cqcSeverity(String? rating) {
  switch (rating) {
    case 'Outstanding':
      return 'info';
    case 'Good':
      return 'normal';
    case 'Requires improvement':
      return 'medium';
    case 'Inadequate':
      return 'critical';
    default:
      return 'low';
  }
}
