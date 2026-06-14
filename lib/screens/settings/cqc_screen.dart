import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/cqc.dart';
import '../../services/cqc_service.dart';
import '../../widgets/common/status_pill.dart';

/// Admin screen to link a CQC location ID to the active home.
/// Find your location ID at cqc.org.uk — it's in the page URL:
/// https://www.cqc.org.uk/location/1-XXXXXXXXX
class CqcScreen extends StatefulWidget {
  const CqcScreen({super.key});
  @override
  State<CqcScreen> createState() => _CqcScreenState();
}

class _CqcScreenState extends State<CqcScreen> {
  final _service = CqcService();
  final _controller = TextEditingController();
  CqcLocation? _result;
  bool _loading = false;
  bool _linking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final id = _controller.text.trim();
    if (id.isEmpty) return;
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      _result = await _service.location(id);
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _link() async {
    if (_result == null) return;
    setState(() => _linking = true);
    try {
      await _service.linkHome(_result!.locationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Linked ${_result!.name ?? _result!.locationId} to this home')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CQC registration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Enter your CQC location ID to link its rating to this home.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 4),
          const Text(
            'Find it at cqc.org.uk — search your home and copy the ID from the page URL (e.g. 1-123456789).',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'CQC location ID',
              prefixIcon: Icon(Icons.verified_outlined),
              hintText: '1-XXXXXXXXX',
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _verify,
            icon: _loading
                ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
            label: Text(_loading ? 'Looking up CQC…' : 'Verify location'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.critical)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                        _result!.registrationStatus == 'Registered'
                            ? Icons.verified
                            : Icons.gpp_bad,
                        color: _result!.registrationStatus == 'Registered'
                            ? AppTheme.ok
                            : AppTheme.critical,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _result!.registrationStatus ?? 'Unknown status',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      _result!.name ?? _result!.locationId,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    if (_result!.postalCode != null)
                      Text(_result!.postalCode!, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 12),
                    if (_result!.overallRating != null)
                      StatusPill(
                        label: _result!.overallRating!.toUpperCase(),
                        severity: cqcSeverity(_result!.overallRating),
                      )
                    else
                      const Text('No rating yet', style: TextStyle(color: Colors.black54)),
                    if (_result!.ratingDate != null) ...[
                      const SizedBox(height: 4),
                      Text('Rated ${_result!.ratingDate}',
                          style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _linking ? null : _link,
                        icon: const Icon(Icons.link),
                        label: Text(_linking ? 'Linking…' : 'Link to this home'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
