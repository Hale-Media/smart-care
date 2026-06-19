import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/care_intervention.dart';
import '../../models/care_plan_section.dart';
import '../../models/resident.dart';
import '../../services/care_intervention_service.dart';
import '../../services/care_plan_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';

class CarePlanScreen extends StatefulWidget {
  final Resident resident;
  const CarePlanScreen({super.key, required this.resident});

  @override
  State<CarePlanScreen> createState() => _CarePlanScreenState();
}

class _CarePlanScreenState extends State<CarePlanScreen> {
  final _planService = CarePlanService();
  final _interventionService = CareInterventionService();

  List<CarePlanSection> _sections = [];
  List<CareIntervention> _interventions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _planService.activeSections(widget.resident.id),
        _interventionService.forResident(widget.resident.id),
      ]);
      if (mounted) {
        setState(() {
          _sections = results[0] as List<CarePlanSection>;
          _interventions = results[1] as List<CareIntervention>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addIntervention(
    int sectionId,
    String description,
    String? frequency,
  ) async {
    await _interventionService.create(
      residentId: widget.resident.id,
      sectionId: sectionId,
      description: description,
      frequency: frequency,
    );
    await _reloadInterventions();
  }

  Future<void> _stopIntervention(int id) async {
    await _interventionService.stop(id);
    await _reloadInterventions();
  }

  Future<void> _reloadInterventions() async {
    final updated = await _interventionService.forResident(widget.resident.id);
    if (mounted) setState(() => _interventions = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Care plan · ${widget.resident.firstName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add section'),
        onPressed: _showAddSheet,
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _sections.isEmpty
                  ? const EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No care plan sections yet',
                      subtitle: 'Tap + to add the first one.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                        itemCount: _sections.length,
                        itemBuilder: (_, i) {
                          final section = _sections[i];
                          final sectionInterventions = _interventions
                              .where((v) => v.sectionId == section.id)
                              .toList();
                          return _SectionCard(
                            section: section,
                            interventions: sectionInterventions,
                            onReview: () => _showReviewSheet(section),
                            onHistory: () => _showHistory(section.domain),
                            onAddIntervention: (desc, freq) =>
                                _addIntervention(section.id, desc, freq),
                            onStopIntervention: _stopIntervention,
                          );
                        },
                      ),
                    ),
    );
  }

  Future<void> _showAddSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SectionFormSheet(
        residentId: widget.resident.id,
        service: _planService,
      ),
    );
    if (created == true) _load();
  }

  Future<void> _showReviewSheet(CarePlanSection section) async {
    final reviewed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SectionFormSheet(
        residentId: widget.resident.id,
        service: _planService,
        existing: section,
      ),
    );
    if (reviewed == true) _load();
  }

  Future<void> _showHistory(String domain) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HistorySheet(
        residentId: widget.resident.id,
        domain: domain,
        service: _planService,
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatefulWidget {
  final CarePlanSection section;
  final List<CareIntervention> interventions;
  final VoidCallback onReview;
  final VoidCallback onHistory;
  final Future<void> Function(String description, String? frequency) onAddIntervention;
  final Future<void> Function(int id) onStopIntervention;

  const _SectionCard({
    required this.section,
    required this.interventions,
    required this.onReview,
    required this.onHistory,
    required this.onAddIntervention,
    required this.onStopIntervention,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _showInterventions = false;

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final overdue = section.isOverdue;
    final count = widget.interventions.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    domainLabel(section.domain),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (overdue)
                  const StatusPill(label: 'Review overdue', severity: 'high')
                else if (section.reviewDue != null)
                  StatusPill(label: 'Due ${section.reviewDueLabel}', severity: 'info'),
                const SizedBox(width: 6),
                Text(
                  'v${section.versionNo}',
                  style: const TextStyle(color: Colors.black38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              section.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (section.whatMattersToMe != null) ...[
              const SizedBox(height: 8),
              _Field('What matters to me', section.whatMattersToMe!,
                  icon: Icons.favorite_border),
            ],
            const SizedBox(height: 8),
            _Field('How to support me', section.howToSupportMe,
                icon: Icons.support_agent_outlined),
            if (section.goals != null) ...[
              const SizedBox(height: 6),
              _Field('Goals', section.goals!, icon: Icons.flag_outlined),
            ],
            if (section.agreedWith != null) ...[
              const SizedBox(height: 4),
              Text(
                'Agreed with: ${section.agreedWith}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],

            // ── Interventions toggle ──
            const SizedBox(height: 10),
            const Divider(height: 1),
            InkWell(
              onTap: () => setState(() => _showInterventions = !_showInterventions),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.checklist_rtl_outlined,
                      size: 16,
                      color: count > 0 ? AppTheme.primary : Colors.black38,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      count == 0
                          ? 'Interventions'
                          : 'Interventions ($count)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: count > 0 ? AppTheme.primary : Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showInterventions
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: Colors.black38,
                    ),
                  ],
                ),
              ),
            ),
            if (_showInterventions) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add intervention'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: _showAddInterventionSheet,
                ),
              ),
              if (widget.interventions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'No active interventions.',
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                )
              else
                ...widget.interventions.map(
                  (v) => _InterventionTile(
                    intervention: v,
                    onStop: () => _confirmStop(v),
                  ),
                ),
              const SizedBox(height: 4),
            ],
            const Divider(height: 1),

            // ── Action buttons ──
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('History'),
                  onPressed: widget.onHistory,
                ),
                const SizedBox(width: 6),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(80, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  onPressed: widget.onReview,
                  child: const Text('Review'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddInterventionSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InterventionFormSheet(
        onSave: widget.onAddIntervention,
      ),
    );
  }

  Future<void> _confirmStop(CareIntervention v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stop intervention?'),
        content: Text('"${v.description}" will be marked as stopped.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.onStopIntervention(v.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }
}

// ── Intervention tile ─────────────────────────────────────────────────────────

class _InterventionTile extends StatelessWidget {
  final CareIntervention intervention;
  final VoidCallback onStop;

  const _InterventionTile({required this.intervention, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.arrow_right, size: 18, color: Colors.black38),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intervention.description,
                  style: const TextStyle(fontSize: 13),
                ),
                if (intervention.frequency != null)
                  Text(
                    intervention.frequency!,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onStop,
            child: const Tooltip(
              message: 'Stop intervention',
              child: Icon(Icons.stop_circle_outlined,
                  size: 18, color: Colors.black38),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add intervention sheet ────────────────────────────────────────────────────

class _InterventionFormSheet extends StatefulWidget {
  final Future<void> Function(String description, String? frequency) onSave;

  const _InterventionFormSheet({required this.onSave});

  @override
  State<_InterventionFormSheet> createState() => _InterventionFormSheetState();
}

class _InterventionFormSheetState extends State<_InterventionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _freqCtrl = TextEditingController();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _descCtrl.dispose();
    _freqCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _saveError = null; });
    try {
      await widget.onSave(
        _descCtrl.text.trim(),
        _freqCtrl.text.trim().isEmpty ? null : _freqCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _saveError = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add intervention',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'e.g. Reposition every 2 hours',
              ),
              maxLines: 2,
              minLines: 1,
              autofocus: true,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _freqCtrl,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                hintText: 'e.g. Every 2 hours, twice daily',
              ),
            ),
            const SizedBox(height: 20),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _saveError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add intervention'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared field widget ───────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Field(this.label, this.value, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54)),
              Text(value, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Add / Review section form sheet ──────────────────────────────────────────

class _SectionFormSheet extends StatefulWidget {
  final int residentId;
  final CarePlanService service;
  final CarePlanSection? existing;

  const _SectionFormSheet({
    required this.residentId,
    required this.service,
    this.existing,
  });

  @override
  State<_SectionFormSheet> createState() => _SectionFormSheetState();
}

class _SectionFormSheetState extends State<_SectionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late String _domain;
  late final _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _support = TextEditingController(
    text: widget.existing?.howToSupportMe ?? '',
  );
  late final _whatMatters = TextEditingController(
    text: widget.existing?.whatMattersToMe ?? '',
  );
  late final _goals = TextEditingController(
    text: widget.existing?.goals ?? '',
  );
  late final _agreedWith = TextEditingController(
    text: widget.existing?.agreedWith ?? '',
  );
  DateTime? _reviewDue;
  late final _reviewDueCtrl = TextEditingController(
    text: widget.existing?.reviewDue != null
        ? DateFormat('d MMM yyyy').format(widget.existing!.reviewDue!)
        : '',
  );

  @override
  void initState() {
    super.initState();
    _domain = widget.existing?.domain ?? carePlanDomains.first;
    _reviewDue = widget.existing?.reviewDue;
  }

  @override
  void dispose() {
    _title.dispose();
    _support.dispose();
    _whatMatters.dispose();
    _goals.dispose();
    _agreedWith.dispose();
    _reviewDueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReviewDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reviewDue ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _reviewDue = picked;
        _reviewDueCtrl.text = DateFormat('d MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final reviewDueStr = _reviewDue != null
          ? DateFormat('yyyy-MM-dd').format(_reviewDue!)
          : null;
      if (widget.existing == null) {
        await widget.service.create(
          residentId: widget.residentId,
          domain: _domain,
          title: _title.text.trim(),
          howToSupportMe: _support.text.trim(),
          whatMattersToMe: _whatMatters.text.trim().isEmpty
              ? null
              : _whatMatters.text.trim(),
          goals: _goals.text.trim().isEmpty ? null : _goals.text.trim(),
          agreedWith: _agreedWith.text.trim().isEmpty
              ? null
              : _agreedWith.text.trim(),
          reviewDue: reviewDueStr,
        );
      } else {
        await widget.service.review(widget.existing!.id, {
          'title': _title.text.trim(),
          'how_to_support_me': _support.text.trim(),
          'what_matters_to_me': _whatMatters.text.trim().isEmpty
              ? null
              : _whatMatters.text.trim(),
          'goals': _goals.text.trim().isEmpty ? null : _goals.text.trim(),
          'agreed_with': _agreedWith.text.trim().isEmpty
              ? null
              : _agreedWith.text.trim(),
          'review_due': reviewDueStr,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
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
    final isReview = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isReview ? 'Review section' : 'Add care plan section',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              if (!isReview)
                DropdownButtonFormField<String>(
                  initialValue: _domain,
                  decoration: const InputDecoration(labelText: 'Domain'),
                  items: carePlanDomains
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(domainLabel(d)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _domain = v!),
                ),
              if (!isReview) const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Section title'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _whatMatters,
                decoration: const InputDecoration(
                  labelText: 'What matters to me',
                  hintText: '"I" statement — the resident\'s voice',
                ),
                maxLines: 2,
                minLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _support,
                decoration:
                    const InputDecoration(labelText: 'How to support me *'),
                maxLines: 3,
                minLines: 3,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _goals,
                decoration: const InputDecoration(labelText: 'Goals'),
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _agreedWith,
                decoration: const InputDecoration(
                    labelText: 'Agreed with (resident / family / LPA)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reviewDueCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Review due',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickReviewDue,
                  ),
                ),
                onTap: _pickReviewDue,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(isReview ? 'Save review' : 'Create section'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Version history sheet ─────────────────────────────────────────────────────

class _HistorySheet extends StatefulWidget {
  final int residentId;
  final String domain;
  final CarePlanService service;

  const _HistorySheet({
    required this.residentId,
    required this.domain,
    required this.service,
  });

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  List<CarePlanSection> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.service
        .sectionHistory(widget.residentId, widget.domain)
        .then((h) {
      if (mounted) setState(() { _history = h; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '${domainLabel(widget.domain)} — version history',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_history.isEmpty)
            const Expanded(
              child: Center(child: Text('No history found.')),
            )
          else
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _history.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, i) {
                  final s = _history[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'v${s.versionNo}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('d MMM yyyy').format(s.effectiveFrom),
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const Spacer(),
                            if (s.status == 'active')
                              const StatusPill(
                                label: 'Current',
                                severity: 'info',
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(s.howToSupportMe,
                            style: const TextStyle(fontSize: 13)),
                        if (s.effectiveTo != null)
                          Text(
                            'Superseded ${DateFormat('d MMM yyyy').format(s.effectiveTo!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black38,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
