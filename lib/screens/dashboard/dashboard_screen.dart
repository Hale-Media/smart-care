import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/care_alert.dart';
import '../../providers/alert_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incident_provider.dart';
import '../../providers/resident_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/status_pill.dart';
import '../alerts/alert_detail_screen.dart';
import '../compliance/compliance_dashboard_screen.dart';
import '../handover/handover_screen.dart';
import '../../widgets/home_switcher.dart';
import '../../widgets/home_cqc_badge.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int tabIndex) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final alerts = context.watch<AlertProvider>();
    final residents = context.watch<ResidentProvider>();
    final incidents = context.watch<IncidentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              alerts.load();
              residents.load();
              incidents.load();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await alerts.load();
          await residents.load();
          await incidents.load();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${auth.user?.name ?? 'Carer'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const HomeSwitcher(),
                  const SizedBox(height: 8),
                  const HomeCqcBadge(),
                ],
              ),
            ),
            _kpiRow(context, residents, alerts, incidents, onNavigate),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Active alerts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (alerts.open.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No active alerts — all clear',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              ...alerts.open.take(8).map((a) => _AlertTile(alert: a)),
            _HandoverCard(),
            const _ComplianceCard(),
          ],
        ),
      ),
    );
  }

  Widget _kpiRow(
    BuildContext context,
    ResidentProvider residents,
    AlertProvider alerts,
    IncidentProvider incidents,
    void Function(int) onNav,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.6,
        children: [
          _kpi(
            'Residents',
            '${residents.residents.length}',
            Icons.people,
            AppTheme.primary,
            () => onNav(1),
          ),
          _kpi(
            'Open alerts',
            '${alerts.openCount}',
            Icons.notifications_active,
            AppTheme.warning,
            () => onNav(2),
          ),
          _kpi(
            'Critical',
            '${alerts.criticalCount}',
            Icons.priority_high,
            AppTheme.critical,
            () => onNav(2),
          ),
          _kpi(
            'Incidents',
            '${incidents.openCount}',
            Icons.report_problem_outlined,
            incidents.openCount > 0 ? AppTheme.warning : AppTheme.ok,
            () => onNav(4),
          ),
        ],
      ),
    );
  }

  Widget _kpi(
    String label,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Handover card on dashboard ────────────────────────────────────────────────

class _ComplianceCard extends StatelessWidget {
  const _ComplianceCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE3F2FD),
            child: Icon(Icons.assignment_outlined, color: AppTheme.info),
          ),
          title: const Text(
            'Compliance dashboard',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Consent, reviews, high-risk residents, missed visits & staff competency',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ComplianceDashboardScreen(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HandoverCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE8F5E9),
            child: Icon(Icons.swap_horiz, color: AppTheme.ok),
          ),
          title: const Text(
            'Shift handover',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Read notes from the last shift or write your own',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const HandoverScreen())),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final CareAlert alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.severityColor(
            alert.severity,
          ).withValues(alpha: 0.15),
          child: Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.severityColor(alert.severity),
          ),
        ),
        title: Text(
          alert.type.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${alert.residentName ?? 'Unknown'} · ${alert.location ?? '—'} · ${Fmt.ago(alert.createdAt)}',
        ),
        trailing: StatusPill(
          label: alert.severity.toUpperCase(),
          severity: alert.severity,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlertDetailScreen(alertId: alert.id),
          ),
        ),
      ),
    );
  }
}
