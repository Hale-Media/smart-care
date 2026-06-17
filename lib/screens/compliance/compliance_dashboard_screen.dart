// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/compliance_summary.dart';
import '../../services/compliance_service.dart';
import '../../services/resident_service.dart';
import '../../services/staff_service.dart';
import '../residents/resident_detail_screen.dart';
import '../staff/staff_competency_screen.dart';

class ComplianceDashboardScreen extends StatefulWidget {
  const ComplianceDashboardScreen({super.key});
  @override
  State<ComplianceDashboardScreen> createState() =>
      _ComplianceDashboardScreenState();
}

class _ComplianceDashboardScreenState extends State<ComplianceDashboardScreen> {
  final _service = ComplianceService();
  ComplianceSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _service.summary();
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const _LoadingView()
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : _Body(summary: _summary!, onRefresh: _load),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _Body extends StatelessWidget {
  final ComplianceSummary summary;
  final VoidCallback onRefresh;
  const _Body({required this.summary, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          _SummaryHeader(summary: summary),
          if (summary.consentGaps.isNotEmpty)
            _ConsentSection(items: summary.consentGaps, onRefresh: onRefresh),
          if (summary.overdueReviews.isNotEmpty)
            _ReviewSection(items: summary.overdueReviews, onRefresh: onRefresh),
          if (summary.highRisk.isNotEmpty)
            _HighRiskSection(items: summary.highRisk, onRefresh: onRefresh),
          if (summary.missedVisits.isNotEmpty)
            _MissedVisitsSection(items: summary.missedVisits, onRefresh: onRefresh),
          if (summary.staffIssues.isNotEmpty)
            _StaffSection(items: summary.staffIssues, onRefresh: onRefresh),
          if (summary.totalIssues == 0) const _AllClearView(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Last updated ${DateFormat("HH:mm, d MMM").format(summary.fetchedAt)}',
              style: const TextStyle(fontSize: 11, color: Colors.black38),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final ComplianceSummary summary;
  const _SummaryHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.totalIssues;
    final color = total == 0
        ? AppTheme.ok
        : total <= 2
        ? AppTheme.warning
        : AppTheme.critical;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        color: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(
                  total == 0
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total == 0
                          ? 'No compliance issues found'
                          : '$total compliance item${total == 1 ? "" : "s"} need attention',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (summary.consentGaps.isNotEmpty)
                          _badge(
                            '${summary.consentGaps.length} consent',
                            AppTheme.critical,
                          ),
                        if (summary.overdueReviews.isNotEmpty)
                          _badge(
                            '${summary.overdueReviews.length} reviews',
                            AppTheme.warning,
                          ),
                        if (summary.highRisk.isNotEmpty)
                          _badge(
                            '${summary.highRisk.length} high risk',
                            AppTheme.warning,
                          ),
                        if (summary.missedVisits.isNotEmpty)
                          _badge(
                            '${summary.missedVisits.length} missed visits',
                            AppTheme.critical,
                          ),
                        if (summary.staffIssues.isNotEmpty)
                          _badge(
                            '${summary.staffIssues.length} staff',
                            AppTheme.info,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            initiallyExpanded: true,
            children: children,
          ),
        ),
      ),
    );
  }
}

Widget _riskPill(String risk) {
  final color = switch (risk) {
    'high' => AppTheme.critical,
    'medium' => AppTheme.warning,
    _ => AppTheme.ok,
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      risk.toUpperCase(),
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _ConsentSection extends StatelessWidget {
  final List<ComplianceConsentGap> items;
  final VoidCallback onRefresh;
  const _ConsentSection({required this.items, required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.camera_alt_outlined,
      color: AppTheme.critical,
      title: 'Consent & privacy gaps',
      subtitle:
          '${items.length} resident${items.length == 1 ? "" : "s"} using camera monitoring without recorded consent',
      children: items
          .map(
            (item) => ListTile(
              title: Text(item.fullName),
              subtitle: Text(
                'Camera monitoring · consent: ${item.monitoringConsent.replaceAll("_", " ")}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _open(context, item.id),
            ),
          )
          .toList(),
    );
  }

  void _open(BuildContext context, int id) async {
    try {
      final r = await ResidentService().get(id);
      if (context.mounted)
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResidentDetailScreen(resident: r)),
        );
      onRefresh();
    } catch (_) {}
  }
}

class _ReviewSection extends StatelessWidget {
  final List<ComplianceResident> items;
  final VoidCallback onRefresh;
  const _ReviewSection({required this.items, required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.event_repeat_outlined,
      color: AppTheme.warning,
      title: 'Overdue outcome reviews',
      subtitle:
          '${items.length} resident${items.length == 1 ? "" : "s"} past their scheduled care review date',
      children: items
          .map(
            (item) => ListTile(
              title: Text(item.fullName),
              subtitle: item.outcomeReviewDate == null
                  ? const Text(
                      'No review date set',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    )
                  : Text(
                      'Review was due ${DateFormat("d MMM yyyy").format(item.outcomeReviewDate!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warning,
                      ),
                    ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _open(context, item.id),
            ),
          )
          .toList(),
    );
  }

  void _open(BuildContext context, int id) async {
    try {
      final r = await ResidentService().get(id);
      if (context.mounted)
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResidentDetailScreen(resident: r)),
        );
      onRefresh();
    } catch (_) {}
  }
}

class _HighRiskSection extends StatelessWidget {
  final List<ComplianceHighRisk> items;
  final VoidCallback onRefresh;
  const _HighRiskSection({required this.items, required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.health_and_safety_outlined,
      color: AppTheme.warning,
      title: 'High clinical risk',
      subtitle:
          '${items.length} resident${items.length == 1 ? "" : "s"} with high falls or nutrition risk requiring active monitoring',
      children: items
          .map(
            (item) => ListTile(
              title: Text(item.fullName),
              subtitle: Wrap(
                spacing: 6,
                children: [
                  if (item.fallRisk == 'high')
                    _riskPill('Fall: ${item.fallRisk}'),
                  if (item.nutritionRisk == 'high')
                    _riskPill('Nutrition: ${item.nutritionRisk}'),
                ],
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _open(context, item.id),
            ),
          )
          .toList(),
    );
  }

  void _open(BuildContext context, int id) async {
    try {
      final r = await ResidentService().get(id);
      if (context.mounted)
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResidentDetailScreen(resident: r)),
        );
      onRefresh();
    } catch (_) {}
  }
}

class _MissedVisitsSection extends StatelessWidget {
  final List<ComplianceMissedVisit> items;
  final VoidCallback onRefresh;
  const _MissedVisitsSection({required this.items, required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.home_outlined,
      color: AppTheme.critical,
      title: 'Missed domiciliary visits',
      subtitle:
          '${items.length} home care visit${items.length == 1 ? "" : "s"} unconfirmed and past scheduled time today',
      children: items
          .map(
            (item) => ListTile(
              title: Text(item.fullName),
              subtitle: Text(
                'Scheduled ${item.scheduledTime} — not yet confirmed',
                style: const TextStyle(fontSize: 12, color: AppTheme.critical),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _open(context, item.residentId),
            ),
          )
          .toList(),
    );
  }

  void _open(BuildContext context, int id) async {
    try {
      final r = await ResidentService().get(id);
      if (context.mounted)
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResidentDetailScreen(resident: r)),
        );
      onRefresh();
    } catch (_) {}
  }
}

class _StaffSection extends StatelessWidget {
  final List<ComplianceStaffIssue> items;
  final VoidCallback onRefresh;
  const _StaffSection({required this.items, required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.school_outlined,
      color: AppTheme.info,
      title: 'Staff competency',
      subtitle:
          '${items.length} staff member${items.length == 1 ? "" : "s"} with overdue or missing monitoring competency records',
      children: items
          .map(
            (item) => ListTile(
              title: Text(item.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roleLabel(item.role),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (item.hasNoRecord)
                    const Text(
                      'No competency record on file',
                      style: TextStyle(fontSize: 12, color: AppTheme.info),
                    )
                  else if (item.isOverdue && item.competencyReviewDate != null)
                    Text(
                      'Review overdue since ${DateFormat("d MMM yyyy").format(item.competencyReviewDate!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warning,
                      ),
                    ),
                ],
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _openStaff(context, item),
            ),
          )
          .toList(),
    );
  }

  String _roleLabel(String role) {
    return StaffRole.values
        .firstWhere((e) => e.name == role, orElse: () => StaffRole.carer)
        .label;
  }

  void _openStaff(BuildContext context, ComplianceStaffIssue item) async {
    try {
      final staffList = await StaffService().list();
      final staffUser = staffList.firstWhere((s) => s.id == item.id);
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StaffCompetencyScreen(staff: staffUser),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open staff record: $e')),
        );
      }
    } finally {
      onRefresh();
    }
  }
}

class _AllClearView extends StatelessWidget {
  const _AllClearView();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.verified_outlined, size: 64, color: AppTheme.ok),
          SizedBox(height: 16),
          Text(
            'All compliance checks passed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.ok,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'No overdue reviews, consent gaps, missed visits, or staff issues found.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.black26),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
