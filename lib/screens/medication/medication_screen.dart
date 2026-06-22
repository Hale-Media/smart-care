import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../utils/labels.dart';
import '../../models/medication.dart';
import '../../models/resident.dart';
import '../../providers/auth_provider.dart';
import '../../services/medication_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';

class MedicationScreen extends StatefulWidget {
  final Resident resident;
  const MedicationScreen({super.key, required this.resident});
  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen>
    with SingleTickerProviderStateMixin {
  final _service = MedicationService();
  List<Medication> _meds = [];
  List<MarEntry> _todayEntries = [];
  bool _loading = true;
  String? _error;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        _service.forResident(widget.resident.id),
        _service.marHistory(
          residentId: widget.resident.id,
          from: DateTime(now.year, now.month, now.day),
          to: DateTime(now.year, now.month, now.day, 23, 59),
        ),
      ]);
      _meds = results[0] as List<Medication>;
      _todayEntries = results[1] as List<MarEntry>;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openAdministerPage(Medication med, {String? scheduledTime}) async {
    final user = context.read<AuthProvider>().user;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _AdministerPage(
          medication: med,
          staffId: user?.id ?? 0,
          staffName: user?.name ?? '',
          service: _service,
          scheduledTime: scheduledTime,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('MAR entry recorded')));
      _load();
    }
  }

  Future<void> _openAddMedPage({Medication? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddMedicationPage(
          residentId: widget.resident.id,
          requiredMeds: widget.resident.medications,
          service: _service,
          existing: existing,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            existing != null ? 'Medication updated' : 'Medication added'),
      ));
      _load();
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _MarHistoryPage(resident: widget.resident, service: _service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.resident.firstName} · MAR'),
        actions: [
          IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'History',
              onPressed: _openHistory),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Medications'),
            Tab(text: "Today's schedule"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_medication',
        onPressed: _openAddMedPage,
        tooltip: 'Add medication',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : TabBarView(
              controller: _tab,
              children: [
                _buildMedicationsList(),
                _buildTodaySchedule(),
              ],
            ),
    );
  }

  Widget _buildMedicationsList() {
    if (_meds.isEmpty) {
      return const EmptyState(
          icon: Icons.medication_outlined,
          title: 'No medications',
          subtitle: 'Prescribed medications appear here.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _meds.length,
        itemBuilder: (_, i) => _medTile(_meds[i]),
      ),
    );
  }

  Widget _buildTodaySchedule() {
    // Derive scheduled slots from each medication's times list.
    final slots = <_ScheduleSlot>[];
    final prnMeds = <Medication>[];
    final now = TimeOfDay.now();

    for (final med in _meds) {
      if (!med.active) continue;
      if (med.prn) {
        prnMeds.add(med);
        continue;
      }
      for (final t in med.times) {
        final parts = t.split(':');
        if (parts.length != 2) continue;
        final slotHour = int.tryParse(parts[0]) ?? 0;
        final slotMin = int.tryParse(parts[1]) ?? 0;
        final isOverdue = slotHour < now.hour ||
            (slotHour == now.hour && slotMin <= now.minute);
        // Match entry by medication AND the exact scheduled slot time.
        final entry = _todayEntries
            .where((e) =>
                e.medicationId == med.id &&
                e.scheduledFor.hour == slotHour &&
                e.scheduledFor.minute == slotMin)
            .cast<MarEntry?>()
            .firstWhere((_) => true, orElse: () => null);
        slots.add(_ScheduleSlot(
          medication: med,
          time: t,
          entry: entry,
          isOverdue: entry == null && isOverdue,
        ));
      }
    }
    slots.sort((a, b) => a.time.compareTo(b.time));

    if (slots.isEmpty && prnMeds.isEmpty) {
      return const EmptyState(
          icon: Icons.schedule,
          title: 'No scheduled doses today',
          subtitle:
              'Add scheduled medications or use PRN from the Medications tab.');
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        children: [
          ...slots.map((s) => _scheduleTile(s)),
          if (prnMeds.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text('As required (PRN)',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.black54)),
            ),
            ...prnMeds.map((m) => _prnTile(m)),
          ],
        ],
      ),
    );
  }

  Widget _scheduleTile(_ScheduleSlot s) {
    final Color color;
    final IconData icon;
    final String statusLabel;

    if (s.entry != null) {
      final outcome = s.entry!.outcome;
      color = outcome == MarOutcome.given ? AppTheme.ok : AppTheme.warning;
      icon = outcome == MarOutcome.given
          ? Icons.check_circle
          : Icons.info_outline;
      final by = s.entry!.administeredByName != null
          ? ' · ${s.entry!.administeredByName}'
          : '';
      final at = s.entry!.administeredAt != null
          ? DateFormat('HH:mm').format(s.entry!.administeredAt!)
          : '';
      statusLabel = '${Labels.marOutcome(outcome.name)}  $at$by';
    } else if (s.isOverdue) {
      color = AppTheme.critical;
      icon = Icons.warning_amber_rounded;
      statusLabel = 'Overdue';
    } else {
      color = AppTheme.warning;
      icon = Icons.schedule;
      statusLabel = 'Due';
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text('${s.medication.name} ${s.medication.dose}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${s.time}  ·  $statusLabel'),
        trailing: s.entry == null
            ? TextButton(
                onPressed: () => _openAdministerPage(s.medication, scheduledTime: s.time),
                child: const Text('Give'),
              )
            : null,
      ),
    );
  }

  Widget _prnTile(Medication m) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFF8E1),
          child: Icon(Icons.medication, color: AppTheme.warning, size: 20),
        ),
        title: Text('${m.name} ${m.dose}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(m.prnReason ?? 'As required'),
        trailing: TextButton(
          onPressed: () => _openAdministerPage(m),
          child: const Text('Give PRN'),
        ),
      ),
    );
  }

  Widget _medTile(Medication m) {
    String sub =
        '${Labels.medicationRoute(m.route)} · ${m.prn ? 'PRN${m.prnReason != null ? ' – ${m.prnReason}' : ''}' : m.frequency}';
    if (m.times.isNotEmpty) sub += '\n${m.times.join(', ')}';
    if (m.lastAdministeredAt != null) {
      final time = DateFormat('HH:mm d MMM').format(m.lastAdministeredAt!);
      final carerPart = m.lastAdministeredByName != null
          ? ' by ${m.lastAdministeredByName}'
          : '';
      sub += '\nLast given: $time$carerPart';
    }
    return Card(
      child: ListTile(
        leading: Icon(
          m.controlledDrug ? Icons.gpp_maybe : Icons.medication,
          color: m.controlledDrug ? AppTheme.critical : AppTheme.primary,
        ),
        title: Text('${m.name} ${m.dose}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.controlledDrug)
              const StatusPill(label: 'CD', severity: 'high')
            else if (m.prn)
              const StatusPill(label: 'PRN', severity: 'medium'),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
              onPressed: () => _openAddMedPage(existing: m),
            ),
          ],
        ),
        onTap: () => _openAdministerPage(m),
      ),
    );
  }
}

class _ScheduleSlot {
  final Medication medication;
  final String time;
  final MarEntry? entry;
  final bool isOverdue;
  const _ScheduleSlot({
    required this.medication,
    required this.time,
    required this.entry,
    required this.isOverdue,
  });
}

// ── MAR History page ──────────────────────────────────────────────────────────

class _MarHistoryPage extends StatefulWidget {
  final Resident resident;
  final MedicationService service;
  const _MarHistoryPage({required this.resident, required this.service});
  @override
  State<_MarHistoryPage> createState() => _MarHistoryPageState();
}

class _MarHistoryPageState extends State<_MarHistoryPage> {
  List<MarEntry> _entries = [];
  bool _loading = true;
  String? _error;
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _entries = await widget.service.marHistory(
        residentId: widget.resident.id,
        from: DateTime(_from.year, _from.month, _from.day),
        to: DateTime(_to.year, _to.month, _to.day, 23, 59),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
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
        title: Text('${widget.resident.firstName} · MAR history'),
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
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _entries.isEmpty
                  ? const EmptyState(
                      icon: Icons.history,
                      title: 'No entries found',
                      subtitle: 'Try a different date range.')
                  : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: _entries.length,
                  itemBuilder: (_, i) => _entryTile(_entries[i]),
                ),
    );
  }

  Widget _entryTile(MarEntry e) {
    final timeFmt = DateFormat('HH:mm');
    final dayFmt = DateFormat('EEE d MMM');
    final isGiven = e.outcome == MarOutcome.given;
    final color = isGiven ? AppTheme.ok : AppTheme.warning;

    final carerPart =
        e.administeredByName != null ? ' by ${e.administeredByName}' : '';
    final adminTime = e.administeredAt != null
        ? '${timeFmt.format(e.administeredAt!)}$carerPart'
        : null;
    final notesPart = e.notes != null ? '\n${e.notes}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isGiven ? Icons.check_circle : Icons.info_outline,
          color: color,
        ),
        title: Text(
          e.medicationName ?? 'Medication',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${dayFmt.format(e.scheduledFor)} ${timeFmt.format(e.scheduledFor)}'
          '${adminTime != null ? '\n$adminTime' : ''}'
          '\n${Labels.marOutcome(e.outcome.name)}$notesPart',
        ),
        isThreeLine: true,
      ),
    );
  }
}

// ── Administer full-screen page ───────────────────────────────────────────────

class _AdministerPage extends StatefulWidget {
  final Medication medication;
  final int staffId;
  final String staffName;
  final MedicationService service;
  final String? scheduledTime;
  const _AdministerPage({
    required this.medication,
    required this.staffId,
    required this.staffName,
    required this.service,
    this.scheduledTime,
  });
  @override
  State<_AdministerPage> createState() => _AdministerPageState();
}

class _AdministerPageState extends State<_AdministerPage> {
  MarOutcome _outcome = MarOutcome.given;
  final _witness = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _witness.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _resolveScheduledFor() {
    final t = widget.scheduledTime;
    if (t == null) return DateTime.now().toUtc();
    final parts = t.split(':');
    if (parts.length != 2) return DateTime.now().toUtc();
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return DateTime.now().toUtc();
    // Slot times in m.times are stored as UTC strings on the server.
    // Build a UTC datetime so the backend's slot-time lookup matches.
    final today = DateTime.now().toUtc();
    return DateTime.utc(today.year, today.month, today.day, h, m);
  }

  Future<void> _submit() async {
    if (widget.medication.controlledDrug && _witness.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Witness name is required for controlled drugs')),
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final entry = MarEntry(
      id: 0,
      medicationId: widget.medication.id,
      residentId: widget.medication.residentId,
      scheduledFor: _resolveScheduledFor(),
      administeredAt: now,
      administeredByStaffId: widget.staffId,
      administeredByName: widget.staffName,
      outcome: _outcome,
      witnessStaffName:
          _witness.text.trim().isEmpty ? null : _witness.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    try {
      await widget.service.administer(entry);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.medication;
    return Scaffold(
      appBar: AppBar(
        title: Text('${m.name} ${m.dose}'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Administering: ${widget.staffName}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<MarOutcome>(
                  initialValue: _outcome,
                  decoration: const InputDecoration(
                      labelText: 'Outcome', border: OutlineInputBorder()),
                  items: MarOutcome.values
                      .map((o) => DropdownMenuItem(
                          value: o, child: Text(Labels.marOutcome(o.name))))
                      .toList(),
                  onChanged: (v) => setState(() => _outcome = v!),
                ),
                if (m.controlledDrug) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _witness,
                    decoration: const InputDecoration(
                        labelText: 'Witness name (required for CD)',
                        border: OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder()),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: Text(_saving ? 'Saving…' : 'Record administration'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add / edit medication full-screen page ────────────────────────────────────

class _AddMedicationPage extends StatefulWidget {
  final int residentId;
  final List<String> requiredMeds;
  final MedicationService service;
  final Medication? existing;
  const _AddMedicationPage({
    required this.residentId,
    required this.requiredMeds,
    required this.service,
    this.existing,
  });
  @override
  State<_AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<_AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _times = TextEditingController();
  final _prnReason = TextEditingController();
  final _instructions = TextEditingController();
  String _route = 'oral';
  String _frequency = 'once_daily';
  bool _prn = false;
  bool _cd = false;
  bool _saving = false;
  String? _presetMed;

  static const _routes = [
    'oral', 'topical', 'subcutaneous', 'IV', 'inhaler', 'patch', 'drops'
  ];
  static const _frequencies = {
    'once_daily': 'Once daily',
    'twice_daily': 'Twice daily',
    'three_times_daily': 'Three times daily',
    'four_times_daily': 'Four times daily',
    'weekly': 'Weekly',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _dose.text = e.dose;
      _times.text = e.times.join(', ');
      _prnReason.text = e.prnReason ?? '';
      _instructions.text = e.instructions ?? '';
      _route = e.route;
      _frequency = _frequencies.containsKey(e.frequency)
          ? e.frequency
          : 'once_daily';
      _prn = e.prn;
      _cd = e.controlledDrug;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _times.dispose();
    _prnReason.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final med = Medication(
      id: widget.existing?.id ?? 0,
      residentId: widget.residentId,
      name: _name.text.trim(),
      dose: _dose.text.trim(),
      route: _route,
      frequency: _prn ? 'PRN' : _frequency,
      times: _times.text.trim().isEmpty
          ? []
          : _times.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
      prn: _prn,
      prnReason:
          _prn && _prnReason.text.trim().isNotEmpty ? _prnReason.text.trim() : null,
      controlledDrug: _cd,
      instructions: _instructions.text.trim().isEmpty
          ? null
          : _instructions.text.trim(),
    );
    try {
      if (widget.existing != null) {
        await widget.service.update(med);
      } else {
        await widget.service.create(med);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit medication' : 'Add medication'),
        leading: const BackButton(),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.requiredMeds.isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: _presetMed,
                      decoration: const InputDecoration(
                          labelText: 'Select medication',
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— Enter manually —')),
                        ...widget.requiredMeds.map((m) =>
                            DropdownMenuItem(value: m, child: Text(m))),
                      ],
                      onChanged: (v) => setState(() {
                        _presetMed = v;
                        if (v != null) _name.text = v;
                      }),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Medication name',
                        border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dose,
                    decoration: const InputDecoration(
                        labelText: 'Dose (e.g. 5mg)',
                        border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _route,
                    decoration: const InputDecoration(
                        labelText: 'Route', border: OutlineInputBorder()),
                    items: _routes
                        .map((r) => DropdownMenuItem(
                            value: r, child: Text(Labels.medicationRoute(r))))
                        .toList(),
                    onChanged: (v) => setState(() => _route = v!),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _prn,
                    onChanged: (v) => setState(() => _prn = v),
                    title: const Text('PRN (as required)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_prn) ...[
                    TextFormField(
                      controller: _prnReason,
                      decoration: const InputDecoration(
                          labelText: 'PRN reason',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      decoration: const InputDecoration(
                          labelText: 'Frequency',
                          border: OutlineInputBorder()),
                      items: _frequencies.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _frequency = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _times,
                      decoration: const InputDecoration(
                        labelText: 'Administration times',
                        hintText: 'e.g. 08:00, 14:00, 20:00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SwitchListTile(
                    value: _cd,
                    onChanged: (v) => setState(() => _cd = v),
                    title: const Text('Controlled drug (CD)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _instructions,
                    decoration: const InputDecoration(
                        labelText: 'Instructions (optional)',
                        border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: Text(_saving
                      ? 'Saving…'
                      : isEdit
                          ? 'Save changes'
                          : 'Add medication'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
