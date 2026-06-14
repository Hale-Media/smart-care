import '../models/cqc.dart';
import 'api_client.dart';

/// Talks to our backend CQC proxy (the API key stays on the server).
class CqcService {
  final _api = ApiClient.instance;

  Future<CqcVerification> verifyProvider(String providerId) async {
    final res =
        await _api.get('/cqc/verify.php', query: {'provider_id': providerId});
    return CqcVerification.fromJson(res);
  }

  Future<CqcLocation> location(String locationId) async {
    final res = await _api.get('/cqc/location.php', query: {'id': locationId});
    return CqcLocation.fromJson(res['location']);
  }

  /// Verify + save the provider id against the signed-in company (admin only).
  Future<void> linkToCompany(String providerId) =>
      _api.post('/companies/link_cqc.php', {'cqc_provider_id': providerId});
}

extension HomeCqcApi on CqcService {
  Future<HomeCqc> homeRating({bool refresh = false}) async {
    final res = await ApiClient.instance
        .get('/homes/cqc.php', query: {if (refresh) 'refresh': 1});
    return HomeCqc.fromJson(res);
  }

  Future<void> linkHome(String locationId) =>
      ApiClient.instance.post('/homes/link_cqc.php', {'cqc_location_id': locationId});
}
