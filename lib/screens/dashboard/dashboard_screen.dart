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
import '../../models/chc_summary.dart';
import '../../services/chc_service.dart';
import '../../services/medication_service.dart';
import '../../services/round_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/status_pill.dart';
import '../alerts/alert_detail_screen.dart';
import '../compliance/compliance_dashboard_screen.dart';
import '../handover/handover_screen.dart';
import '../medication/medication_screen.dart';
import '../medication/overdue_meds_screen.dart';
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
  final _chcService = ChcService();

  List<DueMedication> _allTodayMeds = [];
  List<DueMedication> _overdueMedsList = [];
  int get _overdueMeds => _overdueMedsList.length;
  int _pendingRounds = 0;
  ChcSummary _chc = const ChcSummary(positivePending: 0, totalDrafts: 0);
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
      final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final results = await Future.wait([
        _medService.dueMedications(from: from, to: to),
        _roundService.due(from: from, to: to),
        _chcService.summary(),
      ]);
      final meds = results[0] as List<DueMedication>;
      final rounds = results[1] as List<CareRound>;
      final chc = results[2] as ChcSummary;
      if (mounted) {
        setState(() {
          _allTodayMeds = meds;
          _overdueMedsList = meds.where((m) => m.isOverdue).toList();
          _pendingRounds = rounds.where((r) => !r.isDone && !r.skipped).length;
          _chc = chc;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _extrasStale = true);
    }
  }

  Future<void> _openOverdueMeds() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const OverdueMedsScreen()),
    );
    _loadExtras();
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
            _DailyMedsCard(
              meds: _allTodayMeds,
              onRefresh: _loadExtras,
            ),
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
            _ChcCard(summary: _chc),
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
              _openOverdueMeds),
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

// ── Daily meds card on dashboard ─────────────────────────────────────────────

class _DailyMedsCard extends StatelessWidget {
  final List<DueMedication> meds;
  final VoidCallback onRefresh;

  const _DailyMedsCard({required this.meds, required this.onRefresh});

  Map<int, List<DueMedication>> _byResident() {
    final map = <int, List<DueMedication>>{};
    for (final m in meds) {
      map.putIfAbsent(m.residentId, () => []).add(m);
    }
    // Sort each resident's slots by time
    for (final slots in map.values) {
      slots.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    }
    // Sort residents: overdue first, then pending, then all-given
    final entries = map.entries.toList()
      ..sort((a, b) {
        final aOverdue = a.value.any((m) => m.isOverdue);
        final bOverdue = b.value.any((m) => m.isOverdue);
        if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
        final aAllGiven = a.value.every((m) => m.given);
        final bAllGiven = b.value.every((m) => m.given);
        if (aAllGiven != bAllGiven) return aAllGiven ? 1 : -1;
        return a.value.first.residentName.compareTo(b.value.first.residentName);
      });
    return Map.fromEntries(entries);
  }

  @override
  Widget build(BuildContext context) {
    if (meds.isEmpty) return const SizedBox.shrink();

    final given = meds.where((m) => m.given).length;
    final total = meds.length;
    final hasOverdue = meds.any((m) => m.isOverdue);
    final headerColor = hasOverdue
        ? AppTheme.critical
        : given == total
            ? AppTheme.ok
            : AppTheme.warning;

    final grouped = _byResident();
    final residents = context.watch<ResidentProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.medication_outlined, size: 18, color: headerColor),
                  const SizedBox(width: 8),
                  Text(
                    "Today's medications",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: headerColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$given / $total',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: headerColor,
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
              ...grouped.entries.map((e) {
                final slots = e.value;
                final resident = residents.byId(e.key);
                final residentGiven = slots.where((m) => m.given).length;
                final residentOverdue = slots.any((m) => m.isOverdue);
                final residentAllGiven = residentGiven == slots.length;

                final Color rowColor;
                final IconData rowIcon;
                if (residentOverdue) {
                  rowColor = AppTheme.critical;
                  rowIcon = Icons.warning_amber_rounded;
                } else if (residentAllGiven) {
                  rowColor = AppTheme.ok;
                  rowIcon = Icons.check_circle;
                } else {
                  rowColor = Colors.black38;
                  rowIcon = Icons.radio_button_unchecked;
                }

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: resident == null
                      ? null
                      : () => Navigator.of(context)
                            .push(MaterialPageRoute(
                              builder: (_) => MedicationScreen(
                                resident: resident,
                                initialTab: 1,
                              ),
                            ))
                            .then((_) => onRefresh()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(rowIcon, color: rowColor, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            slots.first.residentName,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$residentGiven/${slots.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: rowColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 16, color: Colors.black26),
                      ],
                    ),
                  ),
                );
              }),
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

class _ChcCard extends StatelessWidget {
  final ChcSummary summary;
  const _ChcCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final subtitle = summary.positivePending > 0
        ? '${summary.positivePending} positive pending referral${summary.positivePending == 1 ? '' : 's'}'
            '  ·  ${summary.totalDrafts} draft${summary.totalDrafts == 1 ? '' : 's'}'
        : summary.totalDrafts > 0
            ? '${summary.totalDrafts} draft${summary.totalDrafts == 1 ? '' : 's'} in progress'
            : 'No open assessments';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: summary.positivePending > 0
                ? const Color(0xFFFFEBEE)
                : const Color(0xFFE3F2FD),
            child: Icon(
              Icons.health_and_safety_outlined,
              color: summary.positivePending > 0 ? AppTheme.critical : AppTheme.info,
            ),
          ),
          title: const Text(
            'NHS Continuing Healthcare',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitle),
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
