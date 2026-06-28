import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/risk_assessment.dart';
import '../../models/resident.dart';
import '../../services/risk_assessment_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';

class RiskAssessmentScreen extends StatefulWidget {
  final Resident resident;
  const RiskAssessmentScreen({super.key, required this.resident});

  @override
  State<RiskAssessmentScreen> createState() => _RiskAssessmentScreenState();
}

class _RiskAssessmentScreenState extends State<RiskAssessmentScreen> {
  final _service = RiskAssessmentService();
  List<RiskAssessment> _assessments = [];
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
      final a = await _service.activeAssessments(widget.resident.id);
      if (mounted) setState(() => _assessments = a);
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
        title: Text('Risk assessments · ${widget.resident.firstName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New assessment'),
        onPressed: _showAddSheet,
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red)))
              : _assessments.isEmpty
                  ? const EmptyState(
                      icon: Icons.health_and_safety_outlined,
                      title: 'No risk assessments yet',
                      subtitle: 'Tap + to record the first one.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(12, 12, 12, 100),
                        itemCount: _assessments.length,
                        itemBuilder: (_, i) => _AssessmentCard(
                          assessment: _assessments[i],
                          onReassess: () =>
                              _showReassessSheet(_assessments[i]),
                          onHistory: () =>
                              _showHistory(_assessments[i].type),
                        ),
                      ),
                    ),
    );
  }

  Future<void> _showAddSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssessmentFormSheet(
        residentId: widget.resident.id,
        service: _service,
      ),
    );
    if (created == true) _load();
  }

  Future<void> _showReassessSheet(RiskAssessment ra) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssessmentFormSheet(
        residentId: widget.resident.id,
        service: _service,
        existing: ra,
      ),
    );
    if (done == true) _load();
  }

  Future<void> _showHistory(String type) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HistorySheet(
        residentId: widget.resident.id,
        type: type,
        service: _service,
      ),
    );
  }
}

// ── Assessment card ───────────────────────────────────────────────────────────

class _AssessmentCard extends StatelessWidget {
  final RiskAssessment assessment;
  final VoidCallback onReassess;
  final VoidCallback onHistory;

  const _AssessmentCard({
    required this.assessment,
    required this.onReassess,
    required this.onHistory,
  });

  Color _levelColor(String level) {
    switch (level) {
      case 'low':       return Colors.green;
      case 'medium':    return Colors.orange;
      case 'high':      return Colors.deepOrange;
      case 'very_high': return AppTheme.critical;
      default:          return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ra = assessment;
    final overdue = ra.isOverdue;
    final levelColor = _levelColor(ra.riskLevel);

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
                    riskTypeLabel(ra.type),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: levelColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    riskLevelLabel(ra.riskLevel),
                    style: TextStyle(
                      color: levelColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (ra.totalScore != null) ...[
                  Text(
                    'Score: ${ra.totalScore}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Text(
                  'Assessed ${ra.assessedAtLabel}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'v${ra.versionNo}',
                  style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (ra.summary != null) ...[
              const SizedBox(height: 6),
              Text(ra.summary!,
                  style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ],
            if (ra.reviewDue != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 14,
                    color: overdue ? AppTheme.critical : Colors.black45,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Review ${ra.reviewDueLabel}',
                    style: TextStyle(
                      fontSize: 12,
                      color: overdue ? AppTheme.critical : Colors.black54,
                      fontWeight: overdue
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (overdue) ...[
                    const SizedBox(width: 6),
                    const StatusPill(label: 'Overdue', severity: 'high'),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('History'),
                  onPressed: onHistory,
                ),
                const SizedBox(width: 6),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(80, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  onPressed: onReassess,
                  child: const Text('Re-assess'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Re-assess form sheet ────────────────────────────────────────────────

class _AssessmentFormSheet extends StatefulWidget {
  final int residentId;
  final RiskAssessmentService service;
  final RiskAssessment? existing;

  const _AssessmentFormSheet({
    required this.residentId,
    required this.service,
    this.existing,
  });

  @override
  State<_AssessmentFormSheet> createState() => _AssessmentFormSheetState();
}

class _AssessmentFormSheetState extends State<_AssessmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  late String _type;
  late String _riskLevel;
  final _score = TextEditingController();
  final _summary = TextEditingController();
  DateTime? _reviewDue;
  late final _reviewDueCtrl = TextEditingController(
    text: widget.existing?.reviewDue != null
        ? DateFormat('d MMM yyyy').format(widget.existing!.reviewDue!)
        : '',
  );

  @override
  void initState() {
    super.initState();
    _type      = widget.existing?.type ?? riskAssessmentTypes.first;
    _riskLevel = widget.existing?.riskLevel ?? 'low';
    _reviewDue = widget.existing?.reviewDue;
    if (widget.existing?.totalScore != null) {
      _score.text = '${widget.existing!.totalScore}';
    }
    if (widget.existing?.summary != null) {
      _summary.text = widget.existing!.summary!;
    }
  }

  @override
  void dispose() {
    _score.dispose();
    _summary.dispose();
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
    setState(() { _saving = true; _error = null; });
    final scoreVal =
        _score.text.trim().isNotEmpty ? int.tryParse(_score.text.trim()) : null;
    final reviewDueStr = _reviewDue != null
        ? DateFormat('yyyy-MM-dd').format(_reviewDue!)
        : null;
    try {
      if (widget.existing == null) {
        await widget.service.create(
          residentId: widget.residentId,
          type: _type,
          riskLevel: _riskLevel,
          totalScore: scoreVal,
          summary: _summary.text.trim().isEmpty ? null : _summary.text.trim(),
          reviewDue: reviewDueStr,
        );
      } else {
        await widget.service.reassess(widget.existing!.id, {
          'risk_level': _riskLevel,
          'total_score': scoreVal,
          'summary': _summary.text.trim().isEmpty ? null : _summary.text.trim(),
          'review_due': reviewDueStr,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReassess = widget.existing != null;
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      isReassess ? 'Re-assess' : 'New risk assessment',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 44),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
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
              if (!isReassess)
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration:
                      const InputDecoration(labelText: 'Assessment tool'),
                  items: riskAssessmentTypes
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(riskTypeLabel(t)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
              if (!isReassess) const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _riskLevel,
                decoration: const InputDecoration(labelText: 'Risk level *'),
                items: riskLevels
                    .map((l) => DropdownMenuItem(
                          value: l,
                          child: Text(riskLevelLabel(l)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _riskLevel = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _score,
                decoration:
                    const InputDecoration(labelText: 'Total score (optional)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _summary,
                decoration:
                    const InputDecoration(labelText: 'Summary / notes'),
                maxLines: 3,
                minLines: 2,
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
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
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
  final String type;
  final RiskAssessmentService service;

  const _HistorySheet({
    required this.residentId,
    required this.type,
    required this.service,
  });

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  List<RiskAssessment> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.service
        .assessmentHistory(widget.residentId, widget.type)
        .then((h) {
      if (mounted) setState(() { _history = h; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '${riskTypeLabel(widget.type)} — history',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
          if (_loading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
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
                  final ra = _history[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'v${ra.versionNo} · ${ra.assessedAtLabel}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (ra.totalScore != null)
                                Text('Score: ${ra.totalScore}',
                                    style:
                                        const TextStyle(fontSize: 13)),
                              if (ra.summary != null)
                                Text(ra.summary!,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54)),
                            ],
                          ),
                        ),
                        Text(
                          riskLevelLabel(ra.riskLevel),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ra.riskLevel == 'high' ||
                                    ra.riskLevel == 'very_high'
                                ? AppTheme.critical
                                : Colors.black54,
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
