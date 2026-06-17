import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/staff_competency_summary.dart';
import '../../services/staff_competency_service.dart';
import '../../services/staff_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import 'staff_competency_screen.dart';

/// Lists every active staff member with their competency record counts.
/// Tapping a row opens that staff member's full competency records screen.
class StaffCompetencyOverviewScreen extends StatefulWidget {
  const StaffCompetencyOverviewScreen({super.key});

  @override
  State<StaffCompetencyOverviewScreen> createState() =>
      _StaffCompetencyOverviewScreenState();
}

class _StaffCompetencyOverviewScreenState
    extends State<StaffCompetencyOverviewScreen> {
  final _competencyService = StaffCompetencyService();
  final _staffService = StaffService();
  List<StaffCompetencySummary> _items = [];
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
      final items = await _competencyService.overviewAll();
      if (mounted) setState(() => _items = items);
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
        title: const Text('Staff competency'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : _items.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline,
              title: 'No staff found',
              subtitle: 'Add staff members to view their competency records.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                itemCount: _items.length,
                itemBuilder: (context, i) => _tile(_items[i]),
              ),
            ),
    );
  }

  Widget _tile(StaffCompetencySummary s) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    if (s.hasNoRecords) {
      statusColor = AppTheme.critical;
      statusIcon = Icons.error_outline;
      statusLabel = 'No records';
    } else if (s.hasExpired) {
      statusColor = AppTheme.critical;
      statusIcon = Icons.warning_amber_rounded;
      statusLabel = '${s.expired} expired';
    } else if (s.hasExpiring) {
      statusColor = AppTheme.warning;
      statusIcon = Icons.schedule_outlined;
      statusLabel = '${s.expiring} expiring soon';
    } else {
      statusColor = AppTheme.ok;
      statusIcon = Icons.check_circle_outline;
      statusLabel = '${s.valid} valid';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          s.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${s.staffRole.label} · '
          '${s.total} record${s.total == 1 ? "" : "s"} · '
          '$statusLabel',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => _open(s),
      ),
    );
  }

  void _open(StaffCompetencySummary s) async {
    try {
      final staffList = await _staffService.list();
      final staffUser = staffList.firstWhere((u) => u.id == s.id);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StaffCompetencyScreen(staff: staffUser),
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open staff: $e')));
      }
    }
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
