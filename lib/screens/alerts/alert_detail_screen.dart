import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/care_alert.dart';
import '../../providers/alert_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/status_pill.dart';

/// Detail + response workflow for a single alert. Shows live location on an
/// OpenStreetMap (Leaflet via flutter_map) when coordinates are present —
/// used for wandering/elopement scenarios.
class AlertDetailScreen extends StatelessWidget {
  final int alertId;
  const AlertDetailScreen({super.key, required this.alertId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final alert = provider.alerts.firstWhere(
      (a) => a.id == alertId,
      orElse: () => CareAlert(
          id: alertId, type: AlertType.manual, createdAt: DateTime.now()),
    );
    final staffId = context.read<AuthProvider>().user?.id ?? 0;
    final hasLocation = alert.lat != null && alert.lng != null;

    return Scaffold(
      appBar: AppBar(title: Text(alert.type.label)),
      body: ListView(
        children: [
          if (hasLocation)
            SizedBox(
              height: 240,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(alert.lat!, alert.lng!),
                  initialZoom: AppConfig.defaultZoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConfig.osmTileUrl,
                    userAgentPackageName: 'uk.carepackage.app',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(alert.lat!, alert.lng!),
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.location_on,
                          color: AppTheme.critical, size: 48),
                    ),
                  ]),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  StatusPill(
                      label: alert.severity.toUpperCase(),
                      severity: alert.severity),
                  const SizedBox(width: 8),
                  StatusPill(label: alert.status.name, severity: 'info'),
                ]),
                const SizedBox(height: 16),
                _row('Resident', alert.residentName ?? '—'),
                _row('Location', alert.location ?? '—'),
                _row('Raised', Fmt.dateTime(alert.createdAt)),
                _row('Source', alert.source ?? '—'),
                if (alert.message != null) _row('Detail', alert.message!),
                const SizedBox(height: 24),
                if (alert.isOpen) ...[
                  FilledButton.icon(
                    onPressed: () =>
                        provider.acknowledge(alert.id, staffId),
                    icon: const Icon(Icons.check),
                    label: const Text('Acknowledge & respond'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: () => _resolve(context, provider, alert.id),
                    icon: const Icon(Icons.done_all),
                    label: const Text('Mark resolved'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(k,
                    style: const TextStyle(
                        color: Colors.black54, fontWeight: FontWeight.w600))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 16))),
          ],
        ),
      );

  Future<void> _resolve(
      BuildContext context, AlertProvider provider, int id) async {
    final ctrl = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resolve alert'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Resolution notes'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Resolve')),
        ],
      ),
    );
    if (notes != null) {
      await provider.resolve(id, notes: notes);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
