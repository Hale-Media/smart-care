import '../models/compliance_summary.dart';
import 'api_client.dart';

class ComplianceService {
  final _api = ApiClient.instance;

  Future<ComplianceSummary> summary() async {
    final res = await _api.get('/compliance/summary.php');
    return ComplianceSummary.fromJson(res);
  }
}
