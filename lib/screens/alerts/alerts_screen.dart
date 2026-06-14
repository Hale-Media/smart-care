import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/care_alert.dart';
import '../../providers/alert_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';
import 'alert_detail_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _openOnly = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final alerts = _openOnly ? provider.open : provider.alerts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          Row(
            children: [
              const Text('Open only', style: TextStyle(fontSize: 13)),
              Switch(
                value: _openOnly,
                onChanged: (v) => setState(() => _openOnly = v),
              ),
            ],
          ),
        ],
      ),
      body: provider.loading
          ? const LoadingView()
          : alerts.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: 'No alerts',
                  subtitle: 'Active alerts will appear here in real time.')
              : RefreshIndicator(
                  onRefresh: provider.load,
                  child: ListView.builder(
                    itemCount: alerts.length,
                    itemBuilder: (_, i) => _AlertCard(alert: alerts[i]),
                  ),
                ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final CareAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.severityColor(alert.severity);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: c.withValues(alpha: 0.15),
          child: Icon(Icons.warning_amber_rounded, color: c),
        ),
        title: Text(alert.type.label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${alert.residentName ?? 'Unknown'} · ${alert.location ?? '—'}\n${Fmt.ago(alert.createdAt)} · ${alert.status.name}'),
        isThreeLine: true,
        trailing: StatusPill(
            label: alert.severity.toUpperCase(), severity: alert.severity),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AlertDetailScreen(alertId: alert.id),
        )),
      ),
    );
  }
}
