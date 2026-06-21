import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/capacity_assessment.dart';
import '../../models/resident.dart';
import '../../services/capacity_assessment_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';

class CapacityAssessmentsScreen extends StatefulWidget {
  final Resident resident;
  const CapacityAssessmentsScreen({super.key, required this.resident});

  @override
  State<CapacityAssessmentsScreen> createState() =>
      _CapacityAssessmentsScreenState();
}

class _CapacityAssessmentsScreenState extends State<CapacityAssessmentsScreen> {
  final _service = CapacityAssessmentService();
  List<CapacityAssessment> _assessments = [];
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
      final records = await _service.activeAssessments(widget.resident.id);
      if (mounted) setState(() => _assessments = records);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(CapacityAssessment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete assessment?'),
        content: Text('"${a.decision}" assessment will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _service.delete(a.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Capacity (MCA) · ${widget.resident.firstName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add assessment'),
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _AssessmentFormSheet(
              residentId: widget.resident.id,
              service: _service,
            ),
          );
          if (created == true) _load();
        },
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : _assessments.isEmpty
          ? const EmptyState(
              icon: Icons.psychology_outlined,
              title: 'No capacity assessments',
              subtitle: 'Tap + to record an MCA assessment.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: _assessments.length,
                itemBuilder: (_, i) {
                  final a = _assessments[i];
                  return _AssessmentCard(
                    assessment: a,
                    service: _service,
                    residentId: widget.resident.id,
                    onDelete: () => _confirmDelete(a),
                    onReassessed: _load,
                    onHistoryPressed: () => _showHistory(a),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _showHistory(CapacityAssessment a) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HistorySheet(
        residentId: widget.resident.id,
        decision: a.decision,
        service: _service,
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  final CapacityAssessment assessment;
  final CapacityAssessmentService service;
  final int residentId;
  final VoidCallback onDelete;
  final VoidCallback onReassessed;
  final VoidCallback onHistoryPressed;

  const _AssessmentCard({
    required this.assessment,
    required this.service,
    required this.residentId,
    required this.onDelete,
    required this.onReassessed,
    required this.onHistoryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final a = assessment;
    final capacityColor = a.hasCapacity ? Colors.green : AppTheme.critical;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.decision,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  'v${a.versionNo}',
                  style: const TextStyle(color: Colors.black38, fontSize: 12),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.black38,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: capacityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: capacityColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    a.hasCapacity ? 'Has capacity' : 'Lacks capacity',
                    style: TextStyle(
                      color: capacityColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (a.isOverdue) ...[
                  const SizedBox(width: 6),
                  const StatusPill(label: 'Review overdue', severity: 'high'),
                ],
              ],
            ),
            if (a.assessmentSummary != null) ...[
              const SizedBox(height: 8),
              Text(a.assessmentSummary!, style: const TextStyle(fontSize: 13)),
            ],
            if (!a.hasCapacity && a.bestInterests != null) ...[
              const SizedBox(height: 6),
              Text(
                'Best interests: ${a.bestInterests}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
            if (a.reviewDue != null) ...[
              const SizedBox(height: 4),
              Text(
                'Review due: ${fmt.format(a.reviewDue!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: a.isOverdue ? AppTheme.critical : Colors.black54,
                  fontWeight: a.isOverdue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('History'),
                  onPressed: onHistoryPressed,
                ),
                const SizedBox(width: 6),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(80, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  onPressed: () => _showReassessSheet(context),
                  child: const Text('Re-assess'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReassessSheet(BuildContext context) async {
    final reassessed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ReassessFormSheet(existing: assessment, service: service),
    );
    if (reassessed == true) onReassessed();
  }
}

class _AssessmentFormSheet extends StatefulWidget {
  final int residentId;
  final CapacityAssessmentService service;

  const _AssessmentFormSheet({required this.residentId, required this.service});

  @override
  State<_AssessmentFormSheet> createState() => _AssessmentFormSheetState();
}

class _AssessmentFormSheetState extends State<_AssessmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  bool _hasCapacity = true;

  final _decision = TextEditingController();
  final _summary = TextEditingController();
  final _bestInterests = TextEditingController();

  DateTime? _reviewDue;
  final _reviewDueCtrl = TextEditingController();

  @override
  void dispose() {
    _decision.dispose();
    _summary.dispose();
    _bestInterests.dispose();
    _reviewDueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReviewDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.create(
        residentId: widget.residentId,
        decision: _decision.text.trim(),
        hasCapacity: _hasCapacity,
        assessmentSummary: _summary.text.trim().isEmpty
            ? null
            : _summary.text.trim(),
        bestInterests: _bestInterests.text.trim().isEmpty
            ? null
            : _bestInterests.text.trim(),
        reviewDue: _reviewDue != null
            ? DateFormat('yyyy-MM-dd').format(_reviewDue!)
            : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheetBody(
      title: 'Add assessment',
      formKey: _formKey,
      saving: _saving,
      error: _error,
      hasCapacity: _hasCapacity,
      onCapacityChanged: (v) => setState(() => _hasCapacity = v),
      decision: _decision,
      summary: _summary,
      bestInterests: _bestInterests,
      reviewDueCtrl: _reviewDueCtrl,
      onPickReviewDue: _pickReviewDue,
      onSave: _save,
      showDecisionField: true,
    );
  }
}

class _ReassessFormSheet extends StatefulWidget {
  final CapacityAssessment existing;
  final CapacityAssessmentService service;

  const _ReassessFormSheet({required this.existing, required this.service});

  @override
  State<_ReassessFormSheet> createState() => _ReassessFormSheetState();
}

class _ReassessFormSheetState extends State<_ReassessFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  late bool _hasCapacity;

  late final _summary = TextEditingController(
    text: widget.existing.assessmentSummary ?? '',
  );
  late final _bestInterests = TextEditingController(
    text: widget.existing.bestInterests ?? '',
  );
  DateTime? _reviewDue;
  late final _reviewDueCtrl = TextEditingController(
    text: widget.existing.reviewDue != null
        ? DateFormat('d MMM yyyy').format(widget.existing.reviewDue!)
        : '',
  );

  @override
  void initState() {
    super.initState();
    _hasCapacity = widget.existing.hasCapacity;
    _reviewDue = widget.existing.reviewDue;
  }

  @override
  void dispose() {
    _summary.dispose();
    _bestInterests.dispose();
    _reviewDueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReviewDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reviewDue ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.reassess(
        widget.existing.id,
        hasCapacity: _hasCapacity,
        assessmentSummary: _summary.text.trim().isEmpty
            ? null
            : _summary.text.trim(),
        bestInterests: _bestInterests.text.trim().isEmpty
            ? null
            : _bestInterests.text.trim(),
        reviewDue: _reviewDue != null
            ? DateFormat('yyyy-MM-dd').format(_reviewDue!)
            : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheetBody(
      title: 'Re-assess: ${widget.existing.decision}',
      formKey: _formKey,
      saving: _saving,
      error: _error,
      hasCapacity: _hasCapacity,
      onCapacityChanged: (v) => setState(() => _hasCapacity = v),
      decision: null,
      summary: _summary,
      bestInterests: _bestInterests,
      reviewDueCtrl: _reviewDueCtrl,
      onPickReviewDue: _pickReviewDue,
      onSave: _save,
      showDecisionField: false,
    );
  }
}

class _FormSheetBody extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final bool saving;
  final String? error;
  final bool hasCapacity;
  final ValueChanged<bool> onCapacityChanged;
  final TextEditingController? decision;
  final TextEditingController summary;
  final TextEditingController bestInterests;
  final TextEditingController reviewDueCtrl;
  final VoidCallback onPickReviewDue;
  final VoidCallback onSave;
  final bool showDecisionField;

  const _FormSheetBody({
    required this.title,
    required this.formKey,
    required this.saving,
    this.error,
    required this.hasCapacity,
    required this.onCapacityChanged,
    required this.decision,
    required this.summary,
    required this.bestInterests,
    required this.reviewDueCtrl,
    required this.onPickReviewDue,
    required this.onSave,
    required this.showDecisionField,
  });

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
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 44),
                    ),
                    onPressed: saving ? null : onSave,
                    child: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (showDecisionField) ...[
                TextFormField(
                  controller: decision,
                  decoration: const InputDecoration(
                    labelText: 'Decision being assessed *',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Text('Has capacity:', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Yes')),
                      ButtonSegment(value: false, label: Text('No')),
                    ],
                    selected: {hasCapacity},
                    onSelectionChanged: (s) => onCapacityChanged(s.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: summary,
                decoration: const InputDecoration(
                  labelText: 'Assessment summary',
                ),
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: bestInterests,
                decoration: const InputDecoration(
                  labelText: 'Best interests decision',
                ),
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reviewDueCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Review due',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: onPickReviewDue,
                  ),
                ),
                onTap: onPickReviewDue,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorySheet extends StatefulWidget {
  final int residentId;
  final String decision;
  final CapacityAssessmentService service;

  const _HistorySheet({
    required this.residentId,
    required this.decision,
    required this.service,
  });

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  List<CapacityAssessment> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.service.history(widget.residentId, widget.decision).then((h) {
      if (mounted) {
        setState(() {
          _history = h;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '${widget.decision} — history',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_history.isEmpty)
            const Expanded(child: Center(child: Text('No history found.')))
          else
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _history.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, i) {
                  final a = _history[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'v${a.versionNo}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              fmt.format(a.createdAt),
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const Spacer(),
                            if (a.status == 'active')
                              const StatusPill(
                                label: 'Current',
                                severity: 'info',
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.hasCapacity ? 'Has capacity' : 'Lacks capacity',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: a.hasCapacity
                                ? Colors.green
                                : AppTheme.critical,
                          ),
                        ),
                        if (a.assessmentSummary != null)
                          Text(
                            a.assessmentSummary!,
                            style: const TextStyle(fontSize: 13),
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
