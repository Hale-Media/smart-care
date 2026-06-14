import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/incident.dart';
import '../../models/resident.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resident_provider.dart';
import '../../services/incident_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import 'incident_form_screen.dart';

/// Home-wide incident list with optional per-resident filtering.
class IncidentsScreen extends StatefulWidget {
  final int? residentId;
  const IncidentsScreen({super.key, this.residentId});
  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  final _service = IncidentService();
  List<Incident> _incidents = [];
  bool _loading = true;
  String? _statusFilter; // null = all
  int? _lastHomeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _incidents = await _service.list(
        status: _statusFilter,
        residentId: widget.residentId,
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openLogForm() async {
    final residents = context.read<ResidentProvider>().residents;
    if (residents.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No residents loaded')));
      return;
    }

    Resident? picked;
    if (residents.length == 1) {
      picked = residents.first;
    } else {
      picked = await showDialog<Resident>(
        context: context,
        builder: (_) => _ResidentPickerDialog(residents: residents),
      );
    }
    if (picked == null || !mounted) return;

    final logged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => IncidentFormScreen(resident: picked!)),
    );
    if (logged == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Incident logged')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeId = context.select<AuthProvider, int?>((a) => a.activeHomeId);
    if (_lastHomeId != null && homeId != _lastHomeId) {
      _lastHomeId = homeId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    } else {
      _lastHomeId ??= homeId;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _filterBar(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_incidents',
        onPressed: _openLogForm,
        icon: const Icon(Icons.add),
        label: const Text('Log incident'),
      ),
      body: _loading
          ? const LoadingView()
          : _incidents.isEmpty
              ? const EmptyState(
                  icon: Icons.report_problem_outlined,
                  title: 'No incidents',
                  subtitle: 'Logged incidents will appear here.')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: _incidents.length,
                    itemBuilder: (_, i) => _tile(_incidents[i]),
                  ),
                ),
    );
  }

  Widget _filterBar() {
    final filters = <String?>[null, 'open', 'investigating', 'closed'];
    final labels = ['All', 'Open', 'Investigating', 'Closed'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: List.generate(filters.length, (i) {
          final selected = _statusFilter == filters[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[i]),
              selected: selected,
              onSelected: (_) {
                setState(() => _statusFilter = filters[i]);
                _load();
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _tile(Incident inc) {
    final severityColor = _severityColor(inc.severity);
    final statusColor = _statusColor(inc.status);
    final fmt = DateFormat('d MMM yyyy, HH:mm');
    final reporterPart =
        inc.reportedByName != null ? ' by ${inc.reportedByName}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    _IncidentDetailPage(incident: inc, service: _service)),
          );
          _load();
        },
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: severityColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${inc.residentName ?? 'Resident'} · ${inc.category}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                          _chip(inc.severity, severityColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fmt.format(inc.occurredAt.toLocal())}$reporterPart',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _chip(inc.status, statusColor),
                          if (inc.cqcNotifiable) ...[
                            const SizedBox(width: 6),
                            _chip('CQC', AppTheme.critical),
                          ],
                          if (inc.safeguardingRaised) ...[
                            const SizedBox(width: 6),
                            _chip('Safeguarding', Colors.purple),
                          ],
                          if (inc.injurySustained) ...[
                            const SizedBox(width: 6),
                            _chip('Injury', AppTheme.warning),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Colors.black26, size: 20),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Color _severityColor(String s) => switch (s) {
        'catastrophic' => AppTheme.critical,
        'major' => AppTheme.critical,
        'moderate' => AppTheme.warning,
        _ => Colors.grey,
      };

  Color _statusColor(String s) => switch (s) {
        'open' => AppTheme.warning,
        'investigating' => AppTheme.primary,
        'closed' => AppTheme.ok,
        _ => Colors.grey,
      };
}

// ── Incident detail + status update ──────────────────────────────────────────

class _IncidentDetailPage extends StatefulWidget {
  final Incident incident;
  final IncidentService service;
  const _IncidentDetailPage(
      {required this.incident, required this.service});
  @override
  State<_IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<_IncidentDetailPage> {
  late Incident _inc;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _inc = widget.incident;
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _saving = true);
    try {
      final updated = await widget.service.update(
        Incident(
          id: _inc.id,
          residentId: _inc.residentId,
          category: _inc.category,
          severity: _inc.severity,
          occurredAt: _inc.occurredAt,
          reportedAt: _inc.reportedAt,
          reportedByStaffId: _inc.reportedByStaffId,
          description: _inc.description,
          status: status,
        ),
      );
      if (mounted) setState(() => _inc = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy, HH:mm');
    final severityColor = _severityColor(_inc.severity);
    final statusColor = _statusColor(_inc.status);
    final reporterPart =
        _inc.reportedByName != null ? ' by ${_inc.reportedByName}' : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_inc.residentName ?? 'Incident'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header chips
          Wrap(spacing: 8, runSpacing: 6, children: [
            _chip(_inc.category, Colors.blueGrey),
            _chip(_inc.severity, severityColor),
            _chip(_inc.status, statusColor),
            if (_inc.cqcNotifiable) _chip('CQC notifiable', AppTheme.critical),
            if (_inc.safeguardingRaised)
              _chip('Safeguarding', Colors.purple),
            if (_inc.injurySustained) _chip('Injury sustained', AppTheme.warning),
            if (_inc.witnessed) _chip('Witnessed', Colors.teal),
          ]),
          const SizedBox(height: 16),
          _row('Occurred', fmt.format(_inc.occurredAt.toLocal())),
          _row('Reported',
              '${fmt.format(_inc.occurredAt.toLocal())}$reporterPart'),
          if (_inc.location != null) _row('Location', _inc.location!),
          const Divider(height: 24),
          _section('What happened', _inc.description),
          if (_inc.immediateAction != null && _inc.immediateAction!.isNotEmpty)
            _section('Immediate action', _inc.immediateAction!),
          _row('Family notified', _inc.familyNotified ? 'Yes' : 'No'),
          _row('GP notified', _inc.gpNotified ? 'Yes' : 'No'),
          const SizedBox(height: 24),
          // Status actions
          if (_inc.status != 'closed') ...[
            const Text('Update status',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            Row(children: [
              if (_inc.status == 'open') ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => _updateStatus('investigating'),
                    child: const Text('Mark investigating'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  onPressed:
                      _saving ? null : () => _updateStatus('closed'),
                  child: const Text('Close incident'),
                ),
              ),
            ]),
          ] else
            _chip('Incident closed', AppTheme.ok),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.black54, fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Widget _section(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 15)),
          ],
        ),
      );

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );

  Color _severityColor(String s) => switch (s) {
        'catastrophic' || 'major' => AppTheme.critical,
        'moderate' => AppTheme.warning,
        _ => Colors.grey,
      };

  Color _statusColor(String s) => switch (s) {
        'open' => AppTheme.warning,
        'investigating' => AppTheme.primary,
        'closed' => AppTheme.ok,
        _ => Colors.grey,
      };
}

// ── Resident picker dialog ────────────────────────────────────────────────────

class _ResidentPickerDialog extends StatelessWidget {
  final List<Resident> residents;
  const _ResidentPickerDialog({required this.residents});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Select resident'),
      children: residents
          .map((r) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, r),
                child: Text(r.fullName),
              ))
          .toList(),
    );
  }
}
