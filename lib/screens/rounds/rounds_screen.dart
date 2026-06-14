import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/care_round.dart';
import '../../models/resident.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resident_provider.dart';
import '../../services/round_service.dart';
import '../../utils/labels.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';

/// Today's welfare/repositioning/continence rounds with completion tracking.
class RoundsScreen extends StatefulWidget {
  const RoundsScreen({super.key});
  @override
  State<RoundsScreen> createState() => _RoundsScreenState();
}

class _RoundsScreenState extends State<RoundsScreen> {
  final _service = RoundService();
  List<CareRound> _rounds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    try {
      _rounds = await _service.due(
        from: DateTime(now.year, now.month, now.day),
        to: DateTime(now.year, now.month, now.day, 23, 59),
      );
      _rounds.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _complete(CareRound r) async {
    final staffId = context.read<AuthProvider>().user?.id ?? 0;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => _CompletionPage(round: r)),
    );
    if (result == null) return;
    final updated = CareRound(
      id: r.id,
      residentId: r.residentId,
      residentName: r.residentName,
      dueAt: r.dueAt,
      completedAt: DateTime.now(),
      completedByStaffId: staffId,
      type: r.type,
      observation: result['observation'] as String?,
      position: result['position'] as String?,
      notes: result['notes'] as String?,
      intakeAmount: result['intake_amount'] as double?,
      intakeUnit: result['intake_unit'] as String?,
    );
    try {
      await _service.complete(updated);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _openSchedule() async {
    final residents = context.read<ResidentProvider>().residents;
    if (residents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No residents loaded')));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SchedulePage(
          residents: residents,
          service: _service,
          onDone: _load,
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _HistoryPage(service: _service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Care rounds'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: _openHistory,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_rounds',
        onPressed: _openSchedule,
        icon: const Icon(Icons.add),
        label: const Text('Schedule'),
      ),
      body: _loading
          ? const LoadingView()
          : _rounds.isEmpty
              ? const EmptyState(
                  icon: Icons.checklist,
                  title: 'No rounds scheduled',
                  subtitle: 'Tap Schedule to add checks for today.')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: _rounds.length + 1,
                    itemBuilder: (_, i) =>
                        i == 0 ? _progressHeader() : _tile(_rounds[i - 1]),
                  ),
                ),
    );
  }

  Widget _progressHeader() {
    final total = _rounds.length;
    final done = _rounds.where((r) => r.isDone).length;
    final overdue = _rounds.where((r) => r.isOverdue).length;
    final progress = total == 0 ? 0.0 : done / total;
    final color = overdue > 0
        ? AppTheme.critical
        : done == total
            ? AppTheme.ok
            : AppTheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('$done / $total checks complete',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const Spacer(),
                  if (overdue > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.critical.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$overdue overdue',
                          style: const TextStyle(
                              color: AppTheme.critical,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(CareRound r) {
    final color = r.isDone
        ? AppTheme.ok
        : (r.isOverdue ? AppTheme.critical : AppTheme.warning);

    String subtitle;
    if (r.isDone) {
      final time = DateFormat('HH:mm').format(r.completedAt!);
      final carerPart = r.completedByName != null ? ' by ${r.completedByName}' : '';
      final obs = r.observation != null ? ' · ${r.observation}' : '';
      subtitle = '$time$carerPart$obs';
    } else {
      subtitle = 'Due ${r.dueLabel}${r.isOverdue ? ' · OVERDUE' : ''}';
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(
              r.isDone ? Icons.check_circle : Icons.schedule,
              color: color,
            ),
            title: Text(
              '${r.residentName ?? 'Resident'} · ${Labels.roundType(r.type)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(subtitle),
          ),
          if (!r.isDone)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton(
                onPressed: () => _complete(r),
                child: const Text('Check'),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Completion full-screen page ───────────────────────────────────────────────

class _CompletionPage extends StatefulWidget {
  final CareRound round;
  const _CompletionPage({required this.round});
  @override
  State<_CompletionPage> createState() => _CompletionPageState();
}

class _CompletionPageState extends State<_CompletionPage> {
  String? _observation;
  String? _position;
  final _notesCtrl = TextEditingController();
  final _intakeCtrl = TextEditingController();
  String _intakeUnit = 'ml';

  static const _observations = ['settled', 'asleep', 'awake', 'distressed'];
  static const _positions = ['left', 'right', 'back'];

  @override
  void dispose() {
    _notesCtrl.dispose();
    _intakeCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final intakeRaw = double.tryParse(_intakeCtrl.text.trim());
    Navigator.pop(context, {
      'observation': _observation,
      'position': _position,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'intake_amount': intakeRaw,
      'intake_unit': intakeRaw != null ? _intakeUnit : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.round.type;
    final isRepositioning = type == 'repositioning';
    final isFluid = type == 'fluid';
    final isFood = type == 'food';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.round.residentName ?? 'Check'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            Labels.roundType(type),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          if (isFluid || isFood) ...[
            Text(
              isFluid ? 'Amount consumed' : 'Amount eaten',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _intakeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isFluid ? 'Volume (ml)' : 'Amount',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                if (isFood) ...[
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _intakeUnit,
                    items: const [
                      DropdownMenuItem(value: 'g', child: Text('g')),
                      DropdownMenuItem(value: '%', child: Text('%')),
                    ],
                    onChanged: (v) => setState(() => _intakeUnit = v!),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('ml',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          const Text('Observation',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _observations
                .map((o) => ChoiceChip(
                      label: Text(Labels.observation(o)),
                      selected: _observation == o,
                      onSelected: (_) => setState(() => _observation = o),
                    ))
                .toList(),
          ),
          if (isRepositioning) ...[
            const SizedBox(height: 24),
            const Text('Position',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _positions
                  .map((p) => ChoiceChip(
                        label: Text(Labels.position(p)),
                        selected: _position == p,
                        onSelected: (_) => setState(() => _position = p),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _observation == null ? null : _confirm,
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: const Text('Confirm check'),
          ),
        ],
      ),
    );
  }
}

// ── History full-screen page ──────────────────────────────────────────────────

class _HistoryPage extends StatefulWidget {
  final RoundService service;
  const _HistoryPage({required this.service});
  @override
  State<_HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<_HistoryPage> {
  List<CareRound> _rounds = [];
  bool _loading = true;
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _rounds = await widget.service.history(
        from: DateTime(_from.year, _from.month, _from.day),
        to: DateTime(_to.year, _to.month, _to.day, 23, 59),
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rounds history'),
        leading: const BackButton(),
        actions: [
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range),
            label: Text('${fmt.format(_from)} – ${fmt.format(_to)}'),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _rounds.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'No rounds found',
                  subtitle: 'Try a different date range.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: _rounds.length,
                  itemBuilder: (_, i) => _historyTile(_rounds[i]),
                ),
    );
  }

  Widget _historyTile(CareRound r) {
    final dayFmt = DateFormat('EEE d MMM');
    final timeFmt = DateFormat('HH:mm');
    final color = r.isDone
        ? AppTheme.ok
        : (r.skipped ? Colors.grey : AppTheme.critical);
    final icon = r.isDone
        ? Icons.check_circle
        : (r.skipped ? Icons.remove_circle_outline : Icons.cancel);

    String status;
    if (r.isDone) {
      final time = timeFmt.format(r.completedAt!);
      final carerPart = r.completedByName != null ? ' · ${r.completedByName}' : '';
      status = 'Completed $time$carerPart';
    } else if (r.skipped) {
      status = 'Skipped';
    } else {
      status = 'Missed';
    }

    final obs = r.observation != null ? '  ${Labels.observation(r.observation!)}' : '';
    final pos = r.position != null ? '  ${Labels.position(r.position!)}' : '';
    final intake = r.intakeAmount != null
        ? '  ${r.intakeAmount!.toStringAsFixed(r.intakeAmount! % 1 == 0 ? 0 : 1)}${r.intakeUnit ?? ''}'
        : '';
    final notes = r.notes != null ? '\n${r.notes}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          '${r.residentName ?? 'Resident'} · ${Labels.roundType(r.type)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${dayFmt.format(r.dueAt)} ${timeFmt.format(r.dueAt)}\n'
          '$status$obs$pos$intake$notes',
        ),
        isThreeLine: true,
      ),
    );
  }
}

// ── Schedule full-screen page ─────────────────────────────────────────────────

class _SchedulePage extends StatefulWidget {
  final List<Resident> residents;
  final RoundService service;
  final VoidCallback onDone;
  const _SchedulePage(
      {required this.residents,
      required this.service,
      required this.onDone});
  @override
  State<_SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<_SchedulePage> {
  Resident? _resident;
  String _type = 'welfare';
  int _intervalHours = 2;
  int _count = 4;
  TimeOfDay _startTime = TimeOfDay.now();
  bool _saving = false;

  static const _types = [
    'welfare',
    'repositioning',
    'continence',
    'fluid',
    'food',
    'night',
  ];

  Future<void> _submit() async {
    if (_resident == null) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final start = DateTime(
        now.year, now.month, now.day, _startTime.hour, _startTime.minute);
    try {
      await widget.service.schedule(
        residentId: _resident!.id,
        type: _type,
        intervalHours: _intervalHours,
        startAt: start,
        count: _count,
      );
      widget.onDone();
      if (mounted) Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule rounds'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Resident>(
            decoration: const InputDecoration(
                labelText: 'Resident', border: OutlineInputBorder()),
            items: widget.residents
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text('${r.firstName} ${r.lastName}'),
                    ))
                .toList(),
            onChanged: (r) => setState(() => _resident = r),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: const InputDecoration(
                labelText: 'Round type', border: OutlineInputBorder()),
            child: DropdownButton<String>(
              value: _type,
              isExpanded: true,
              underline: const SizedBox(),
              items: _types
                  .map((t) => DropdownMenuItem(
                      value: t, child: Text(Labels.roundType(t))))
                  .toList(),
              onChanged: (t) => setState(() => _type = t!),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Interval', border: OutlineInputBorder()),
                child: DropdownButton<int>(
                  value: _intervalHours,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [1, 2, 4, 6]
                      .map((h) => DropdownMenuItem(
                            value: h,
                            child: Text('Every ${h}h'),
                          ))
                      .toList(),
                  onChanged: (h) => setState(() => _intervalHours = h!),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Count', border: OutlineInputBorder()),
                child: DropdownButton<int>(
                  value: _count,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [2, 3, 4, 6, 8, 12]
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text('$c rounds'),
                          ))
                      .toList(),
                  onChanged: (c) => setState(() => _count = c!),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start time'),
            trailing: Text(_startTime.format(context),
                style: const TextStyle(fontSize: 16)),
            onTap: () async {
              final t = await showTimePicker(
                  context: context, initialTime: _startTime);
              if (t != null) setState(() => _startTime = t);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_resident == null || _saving) ? null : _submit,
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Schedule'),
          ),
        ],
      ),
    );
  }
}
