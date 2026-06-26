import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/care_alert.dart';
import '../../models/due_medication.dart';
import '../../models/care_round.dart';
import '../../providers/alert_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incident_provider.dart';
import '../../providers/resident_provider.dart';
import '../../services/medication_service.dart';
import '../../services/round_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/status_pill.dart';
import '../alerts/alert_detail_screen.dart';
import '../compliance/compliance_dashboard_screen.dart';
import '../handover/handover_screen.dart';
import '../../widgets/home_switcher.dart';
import '../../widgets/home_cqc_badge.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _medService = MedicationService();
  final _roundService = RoundService();

  int _overdueMeds = 0;
  int _pendingRounds = 0;
  bool _extrasStale = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadExtras();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      context.read<AlertProvider>().load();
      context.read<ResidentProvider>().load();
      context.read<IncidentProvider>().load();
      _loadExtras();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadExtras() async {
    if (mounted) setState(() => _extrasStale = false);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = DateTime(now.year, now.month, now.day, 23, 59);
      final results = await Future.wait([
        _medService.dueMedications(from: from, to: to),
        _roundService.due(from: from, to: to),
      ]);
      final meds = results[0] as List<DueMedication>;
      final rounds = results[1] as List<CareRound>;
      if (mounted) {
        setState(() {
          _overdueMeds = meds.where((m) => m.isOverdue).length;
          _pendingRounds = rounds.where((r) => !r.isDone && !r.skipped).length;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _extrasStale = true);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<AlertProvider>().load(),
      context.read<ResidentProvider>().load(),
      context.read<IncidentProvider>().load(),
      _loadExtras(),
    ]);
  }

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
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
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
            if (residents.isStale || alerts.isStale || _extrasStale)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, size: 14, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Showing cached data — check your connection',
                        style: TextStyle(fontSize: 12, color: AppTheme.warning),
                      ),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Retry', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            _kpiGrid(context, residents, alerts, incidents),
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

  Widget _kpiGrid(
    BuildContext context,
    ResidentProvider residents,
    AlertProvider alerts,
    IncidentProvider incidents,
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
          _kpi('Residents', '${residents.residents.length}',
              Icons.people, AppTheme.primary, () => widget.onNavigate(1)),
          _kpi('Open alerts', '${alerts.openCount}',
              Icons.notifications_active, AppTheme.warning, () => widget.onNavigate(2)),
          _kpi('Critical', '${alerts.criticalCount}',
              Icons.priority_high, AppTheme.critical, () => widget.onNavigate(2)),
          _kpi('Incidents', '${incidents.openCount}',
              Icons.report_problem_outlined,
              incidents.openCount > 0 ? AppTheme.warning : AppTheme.ok,
              () => widget.onNavigate(4)),
          _kpi('Overdue meds', '$_overdueMeds',
              Icons.medication_outlined,
              _overdueMeds > 0 ? AppTheme.critical : AppTheme.ok,
              () => widget.onNavigate(3)),
          _kpi('Rounds due', '$_pendingRounds',
              Icons.checklist,
              _pendingRounds > 0 ? AppTheme.warning : AppTheme.ok,
              () => widget.onNavigate(3)),
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
