import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/staff_competency_record.dart';
import '../../models/staff_user.dart';
import '../../services/staff_competency_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';

/// Full-page competency record list for a single staff member.
/// Shows all assessed competencies, expiry status, and lets managers add/delete.
class StaffCompetencyScreen extends StatefulWidget {
  final StaffUser staff;
  const StaffCompetencyScreen({super.key, required this.staff});

  @override
  State<StaffCompetencyScreen> createState() => _StaffCompetencyScreenState();
}

class _StaffCompetencyScreenState extends State<StaffCompetencyScreen> {
  final _service = StaffCompetencyService();
  List<StaffCompetencyRecord> _records = [];
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
      final records = await _service.list(widget.staff.id);
      if (mounted) setState(() => _records = records);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(StaffCompetencyRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
          'Remove "${record.competency}" assessed on ${record.assessedDateLabel}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(record.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _showAddDialog() async {
    final competencyCtrl = TextEditingController();
    final assessedByCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime? assessedDate;
    DateTime? expiryDate;
    final assessedCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    var outcome = 'passed';
    bool saving = false;

    // Pre-defined competency options for quick selection.
    const competencyOptions = [
      'Falls risk assessment',
      'Manual handling',
      'Medication administration (MAR)',
      'NEWS2 / clinical deterioration',
      'Infection control',
      'Safeguarding adults',
      'Dementia awareness',
      'Fire safety',
      'First aid',
      'Movement sensor operation',
      'Acoustic monitor operation',
      'Fall detector operation',
      'Camera / surveillance procedures',
      'Mental Capacity Act (MCA)',
      'Nutrition & hydration (MUST)',
      'End of life care',
    ];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Add competency record'),
          scrollable: true,
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Competency name — free text with quick-pick chips
                TextFormField(
                  controller: competencyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Competency *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: competencyOptions
                      .map(
                        (opt) => ActionChip(
                          label: Text(
                            opt,
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setInner(() => competencyCtrl.text = opt),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                // Outcome
                DropdownButtonFormField<String>(
                  initialValue: outcome,
                  decoration: const InputDecoration(
                    labelText: 'Outcome *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'passed', child: Text('Passed')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Pending / in progress'),
                    ),
                  ],
                  onChanged: (v) => setInner(() => outcome = v!),
                ),
                const SizedBox(height: 12),
                // Assessed date
                TextFormField(
                  controller: assessedCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Assessed date *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: assessedDate ?? DateTime.now(),
                          firstDate: DateTime(2015),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setInner(() {
                            assessedDate = picked;
                            assessedCtrl.text = DateFormat(
                              'd MMM yyyy',
                            ).format(picked);
                          });
                        }
                      },
                    ),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: assessedDate ?? DateTime.now(),
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setInner(() {
                        assessedDate = picked;
                        assessedCtrl.text = DateFormat(
                          'd MMM yyyy',
                        ).format(picked);
                      });
                    }
                  },
                  validator: (_) =>
                      assessedDate == null ? 'Select a date' : null,
                ),
                const SizedBox(height: 12),
                // Expiry date
                TextFormField(
                  controller: expiryCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Expiry date (optional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (expiryDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setInner(() {
                              expiryDate = null;
                              expiryCtrl.clear();
                            }),
                          ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate:
                                  expiryDate ??
                                  DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setInner(() {
                                expiryDate = picked;
                                expiryCtrl.text = DateFormat(
                                  'd MMM yyyy',
                                ).format(picked);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate:
                          expiryDate ??
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setInner(() {
                        expiryDate = picked;
                        expiryCtrl.text = DateFormat(
                          'd MMM yyyy',
                        ).format(picked);
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Assessed by
                TextFormField(
                  controller: assessedByCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Assessed by *',
                    hintText: 'e.g. Jane Smith (Manager)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Notes
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setInner(() => saving = true);
                      try {
                        final record = StaffCompetencyRecord(
                          id: 0,
                          staffId: widget.staff.id,
                          competency: competencyCtrl.text.trim(),
                          assessedDate: assessedDate!,
                          expiryDate: expiryDate,
                          assessedBy: assessedByCtrl.text.trim(),
                          outcome: outcome,
                          notes: notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                          createdAt: DateTime.now(),
                        );
                        await _service.create(record);
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      } finally {
                        if (ctx.mounted) setInner(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save record'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Competency records'),
            Text(
              widget.staff.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_competency',
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add record'),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : _records.isEmpty
          ? const EmptyState(
              icon: Icons.school_outlined,
              title: 'No competency records',
              subtitle:
                  'No assessments have been logged for this staff member yet. '
                  'Tap "Add record" below to add one.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                children: [
                  _StatusSummary(records: _records),
                  const SizedBox(height: 8),
                  ..._records.map(_recordCard),
                ],
              ),
            ),
    );
  }

  Widget _recordCard(StaffCompetencyRecord r) {
    final outcomeColor = switch (r.outcome) {
      'passed' => AppTheme.ok,
      'failed' => AppTheme.critical,
      _ => AppTheme.warning,
    };
    final outcomeLabel = switch (r.outcome) {
      'passed' => 'Passed',
      'failed' => 'Failed',
      _ => 'Pending',
    };

    Color? expiryColor;
    String? expiryLabel;
    if (r.isExpired) {
      expiryColor = AppTheme.critical;
      expiryLabel = 'Expired ${r.expiryDateLabel}';
    } else if (r.expiresSoon) {
      expiryColor = AppTheme.warning;
      expiryLabel = 'Expires ${r.expiryDateLabel}';
    } else if (r.expiryDate != null) {
      expiryColor = Colors.black54;
      expiryLabel = 'Expires ${r.expiryDateLabel}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.competency,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _pill(outcomeLabel, outcomeColor),
                      if (expiryLabel != null) _pill(expiryLabel, expiryColor!),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Assessed ${r.assessedDateLabel} by ${r.assessedBy}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (r.notes != null && r.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      r.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.black26,
                size: 20,
              ),
              tooltip: 'Delete record',
              onPressed: () => _delete(r),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
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

// ─── Summary strip ─────────────────────────────────────────────────────────────

class _StatusSummary extends StatelessWidget {
  final List<StaffCompetencyRecord> records;
  const _StatusSummary({required this.records});

  @override
  Widget build(BuildContext context) {
    final passed = records.where((r) => r.outcome == 'passed').length;
    final expired = records.where((r) => r.isExpired).length;
    final expiresSoon = records
        .where((r) => !r.isExpired && r.expiresSoon)
        .length;

    return Card(
      margin: EdgeInsets.zero,
      color: AppTheme.primary.withValues(alpha: 0.05),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat('${records.length}', 'Total', Colors.black54),
            _stat('$passed', 'Passed', AppTheme.ok),
            if (expiresSoon > 0)
              _stat('$expiresSoon', 'Expiring soon', AppTheme.warning),
            if (expired > 0) _stat('$expired', 'Expired', AppTheme.critical),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 22,
          color: color,
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
    ],
  );
}

// ─── Error view ────────────────────────────────────────────────────────────────

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
