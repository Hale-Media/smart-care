import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/chc_checklist.dart';
import '../../models/resident.dart';
import '../../services/chc_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';

const _kDomainKeys = [
  'breathing',
  'nutrition',
  'continence',
  'skin',
  'mobility',
  'communication',
  'psychological',
  'cognition',
  'behaviour',
  'drug_therapies',
  'altered_consciousness',
];

const _kDomainLabels = <String, String>{
  'breathing': 'Breathing',
  'nutrition': 'Nutrition',
  'continence': 'Continence',
  'skin': 'Skin (tissue viability)',
  'mobility': 'Mobility',
  'communication': 'Communication',
  'psychological': 'Psychological & emotional needs',
  'cognition': 'Cognition',
  'behaviour': 'Behaviour',
  'drug_therapies': 'Drug therapies & medication',
  'altered_consciousness': 'Altered states of consciousness',
};

const _kPriorityDomains = {
  'breathing',
  'behaviour',
  'drug_therapies',
  'altered_consciousness',
};

// ── List screen ───────────────────────────────────────────────────────────────

class ChcScreen extends StatefulWidget {
  final Resident resident;
  const ChcScreen({super.key, required this.resident});

  @override
  State<ChcScreen> createState() => _ChcScreenState();
}

class _ChcScreenState extends State<ChcScreen> {
  final _service = ChcService();
  List<ChcChecklist> _checklists = [];
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
      final records = await _service.list(widget.resident.id);
      if (mounted) setState(() => _checklists = records);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(ChcChecklist c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete checklist?'),
        content: const Text('This draft CHC checklist will be removed.'),
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
        await _service.delete(c.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text('CHC Checklist · ${widget.resident.firstName}'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New checklist'),
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => _ChcFormScreen(
                residentId: widget.resident.id,
                residentName: widget.resident.fullName,
                service: _service,
              ),
            ),
          );
          if (created == true) _load();
        },
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _checklists.isEmpty
                  ? const EmptyState(
                      icon: Icons.fact_check_outlined,
                      title: 'No CHC checklists',
                      subtitle: 'Tap + to complete the national screening checklist.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                        itemCount: _checklists.length,
                        itemBuilder: (_, i) {
                          final c = _checklists[i];
                          return _ChcCard(
                            checklist: c,
                            onTap: () async {
                              final changed = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => _ChcFormScreen(
                                    residentId: widget.resident.id,
                                    residentName: widget.resident.fullName,
                                    service: _service,
                                    existingId: c.id,
                                    readOnly: c.isCompleted,
                                  ),
                                ),
                              );
                              if (changed == true) _load();
                            },
                            onDelete: c.isCompleted ? null : () => _confirmDelete(c),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ── List card ─────────────────────────────────────────────────────────────────

class _ChcCard extends StatelessWidget {
  final ChcChecklist checklist;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ChcCard({
    required this.checklist,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = checklist;
    final fmt = DateFormat('d MMM yyyy');
    final outcomeColor = c.isPositive ? Colors.orange[700]! : Colors.green[700]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    fmt.format(c.createdAt),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Spacer(),
                  StatusPill(
                    label: c.isCompleted ? 'Completed' : 'Draft',
                    severity: c.isCompleted ? 'normal' : 'info',
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.black38),
                      onPressed: onDelete,
                      tooltip: 'Delete draft',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: outcomeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: outcomeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  c.isPositive
                      ? 'Positive — refer for DST assessment'
                      : 'Negative — threshold not met',
                  style: TextStyle(
                    color: outcomeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${c.countA}A · ${c.countB}B · ${c.countC}C',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              if (c.isCompleted && c.completedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Signed off ${fmt.format(c.completedAt!)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                ),
              ],
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Tap to view →',
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Form / detail screen ──────────────────────────────────────────────────────

class _ChcFormScreen extends StatefulWidget {
  final int residentId;
  final String residentName;
  final ChcService service;
  final int? existingId;
  final bool readOnly;

  const _ChcFormScreen({
    required this.residentId,
    required this.residentName,
    required this.service,
    this.existingId,
    this.readOnly = false,
  });

  @override
  State<_ChcFormScreen> createState() => _ChcFormScreenState();
}

class _ChcFormScreenState extends State<_ChcFormScreen> {
  ChcChecklist? _existing;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  late final Map<String, String> _levels = {
    for (final k in _kDomainKeys) k: 'C',
  };
  late final Map<String, TextEditingController> _evidence = {
    for (final k in _kDomainKeys) k: TextEditingController(),
  };
  final _rationaleCtrl = TextEditingController();
  bool _personInvolved = false;
  bool _representativeInvolved = false;
  final _representativeNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingId != null) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final c = await widget.service.getOne(widget.existingId!);
      if (!mounted) return;
      _existing = c;
      if (c.domains != null) {
        for (final entry in c.domains!.entries) {
          _levels[entry.key] = entry.value.level;
          _evidence[entry.key]?.text = entry.value.evidence ?? '';
        }
      }
      _rationaleCtrl.text = c.rationale ?? '';
      _personInvolved = c.personInvolved;
      _representativeInvolved = c.representativeInvolved;
      _representativeNameCtrl.text = c.representativeName ?? '';
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _evidence.values) {
      ctrl.dispose();
    }
    _rationaleCtrl.dispose();
    _representativeNameCtrl.dispose();
    super.dispose();
  }

  Map<String, ChcDomain> _buildDomains() {
    return {
      for (final k in _kDomainKeys)
        k: ChcDomain(
          level: _levels[k]!,
          evidence: _evidence[k]!.text.trim().isEmpty ? null : _evidence[k]!.text.trim(),
        ),
    };
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.existingId == null) {
        await widget.service.create(
          residentId: widget.residentId,
          domains: _buildDomains(),
          rationale: _rationaleCtrl.text.trim().isEmpty ? null : _rationaleCtrl.text.trim(),
          personInvolved: _personInvolved,
          representativeName: _representativeNameCtrl.text.trim().isEmpty
              ? null
              : _representativeNameCtrl.text.trim(),
          representativeInvolved: _representativeInvolved,
        );
      } else {
        await widget.service.update(
          widget.existingId!,
          domains: _buildDomains(),
          rationale: _rationaleCtrl.text.trim().isEmpty ? null : _rationaleCtrl.text.trim(),
          personInvolved: _personInvolved,
          representativeName: _representativeNameCtrl.text.trim().isEmpty
              ? null
              : _representativeNameCtrl.text.trim(),
          representativeInvolved: _representativeInvolved,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOff() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CompleteSheet(id: widget.existingId!, service: widget.service),
    );
    if (done == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existingId == null;
    final readOnly = widget.readOnly;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          readOnly
              ? 'CHC Checklist (Completed)'
              : isNew
                  ? 'New CHC Checklist'
                  : 'Edit CHC Checklist',
        ),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'Print / export PDF',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _ChcPrintScreen(
                    checklistId: widget.existingId!,
                    residentName: widget.residentName,
                    service: widget.service,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: readOnly
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (!isNew && _existing != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _signOff,
                          child: const Text('Sign off'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: _loading
          ? const LoadingView()
          : _error != null && _existing == null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    if (_existing?.isCompleted == true) ...[
                      _OutcomeBanner(checklist: _existing!),
                      const SizedBox(height: 12),
                    ],
                    const Text(
                      'Care domains',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Score A (most severe) · B · C (lowest). '
                      'Priority domains (★) trigger a positive outcome on a single A.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    for (final key in _kDomainKeys)
                      _DomainRow(
                        domainKey: key,
                        label: _kDomainLabels[key]!,
                        priority: _kPriorityDomains.contains(key),
                        level: _levels[key]!,
                        evidenceCtrl: _evidence[key]!,
                        readOnly: readOnly,
                        onLevelChanged: readOnly
                            ? null
                            : (v) => setState(() => _levels[key] = v),
                      ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Involvement & rationale',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _personInvolved,
                      onChanged: readOnly
                          ? null
                          : (v) => setState(() => _personInvolved = v ?? false),
                      title: const Text('Person was involved in this checklist'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: _representativeInvolved,
                      onChanged: readOnly
                          ? null
                          : (v) => setState(() => _representativeInvolved = v ?? false),
                      title: const Text('Representative was involved'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_representativeInvolved) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _representativeNameCtrl,
                        readOnly: readOnly,
                        decoration: const InputDecoration(labelText: 'Representative name'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _rationaleCtrl,
                      readOnly: readOnly,
                      maxLines: 4,
                      minLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Rationale / additional notes',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_existing?.isCompleted == true) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      _AssessorSection(checklist: _existing!),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
    );
  }
}

// ── Domain row ────────────────────────────────────────────────────────────────

class _DomainRow extends StatelessWidget {
  final String domainKey;
  final String label;
  final bool priority;
  final String level;
  final TextEditingController evidenceCtrl;
  final bool readOnly;
  final ValueChanged<String>? onLevelChanged;

  const _DomainRow({
    required this.domainKey,
    required this.label,
    required this.priority,
    required this.level,
    required this.evidenceCtrl,
    required this.readOnly,
    this.onLevelChanged,
  });

  Color _levelColor(String l) => switch (l) {
        'A' => Colors.red[700]!,
        'B' => Colors.orange[700]!,
        _ => Colors.green[700]!,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (priority) ...[
                  const Icon(Icons.star, size: 13, color: Colors.orange),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            readOnly
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _levelColor(level).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _levelColor(level).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'Level $level',
                      style: TextStyle(
                        color: _levelColor(level),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'A', label: Text('A')),
                      ButtonSegment(value: 'B', label: Text('B')),
                      ButtonSegment(value: 'C', label: Text('C')),
                    ],
                    selected: {level},
                    onSelectionChanged: onLevelChanged != null
                        ? (s) => onLevelChanged!(s.first)
                        : null,
                  ),
            const SizedBox(height: 8),
            TextField(
              controller: evidenceCtrl,
              readOnly: readOnly,
              decoration: InputDecoration(
                labelText: 'Evidence (optional)',
                isDense: true,
                border: readOnly ? InputBorder.none : null,
              ),
              maxLines: 2,
              minLines: 1,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Outcome banner ────────────────────────────────────────────────────────────

class _OutcomeBanner extends StatelessWidget {
  final ChcChecklist checklist;
  const _OutcomeBanner({required this.checklist});

  @override
  Widget build(BuildContext context) {
    final positive = checklist.isPositive;
    final color = positive ? Colors.orange[700]! : Colors.green[700]!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            positive ? Icons.assignment_late_outlined : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  positive ? 'Outcome: Positive' : 'Outcome: Negative',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  positive
                      ? 'Refer for full CHC Decision Support Tool assessment'
                      : 'Individual does not meet the CHC threshold at this time',
                  style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Assessor section (completed view) ─────────────────────────────────────────

class _AssessorSection extends StatelessWidget {
  final ChcChecklist checklist;
  const _AssessorSection({required this.checklist});

  @override
  Widget build(BuildContext context) {
    final c = checklist;
    final fmt = DateFormat('d MMM yyyy HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Assessor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 6),
        if (c.assessorName != null) Text('Name: ${c.assessorName}'),
        if (c.assessorRole != null) Text('Role: ${c.assessorRole}'),
        if (c.assessorOrg != null) Text('Organisation: ${c.assessorOrg}'),
        if (c.completedAt != null)
          Text('Signed off: ${fmt.format(c.completedAt!)}'),
      ],
    );
  }
}

// ── Sign-off sheet ────────────────────────────────────────────────────────────

class _CompleteSheet extends StatefulWidget {
  final int id;
  final ChcService service;
  const _CompleteSheet({required this.id, required this.service});

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _orgCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.complete(
        widget.id,
        assessorName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        assessorRole: _roleCtrl.text.trim().isEmpty ? null : _roleCtrl.text.trim(),
        assessorOrg: _orgCtrl.text.trim().isEmpty ? null : _orgCtrl.text.trim(),
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
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sign off checklist',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 44),
                  ),
                  onPressed: _saving ? null : _confirm,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Once signed off this checklist is locked and read-only.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Assessor name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleCtrl,
              decoration: const InputDecoration(labelText: 'Assessor role'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _orgCtrl,
              decoration: const InputDecoration(labelText: 'Organisation'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Print / PDF preview screen ────────────────────────────────────────────────

class _ChcPrintScreen extends StatelessWidget {
  final int checklistId;
  final String residentName;
  final ChcService service;

  const _ChcPrintScreen({
    required this.checklistId,
    required this.residentName,
    required this.service,
  });

  Future<Uint8List> _build(PdfPageFormat format) async {
    final c = await service.getOne(checklistId);
    return _buildChcPdf(c, residentName);
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final safeName = residentName.replaceAll(' ', '_');
    return Scaffold(
      appBar: AppBar(title: Text('CHC — $residentName')),
      body: PdfPreview(
        build: _build,
        pdfFileName: 'CHC_${safeName}_$date.pdf',
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
      ),
    );
  }
}

// ── PDF builder ───────────────────────────────────────────────────────────────

Future<Uint8List> _buildChcPdf(ChcChecklist c, String residentName) async {
  final doc = pw.Document();
  final fmt = DateFormat('d MMMM yyyy');
  final positive = c.isPositive;
  final headerColor = PdfColor.fromHex('0B2E33');
  final outcomeColor = positive ? PdfColors.orange800 : PdfColors.green800;

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
    header: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (c.status == 'draft')
          pw.Text(
            'DRAFT - NOT SIGNED OFF',
            style: pw.TextStyle(
              color: PdfColors.red700,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
          ),
        pw.Text(
          'NHS Continuing Healthcare - Checklist',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Screening tool to identify the need for a full assessment of eligibility.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          children: [
            pw.TableRow(children: [
              _metaCell('Name', residentName),
              _metaCell(
                'Date',
                c.completedAt != null
                    ? fmt.format(c.completedAt!)
                    : c.status == 'draft'
                        ? 'Draft - ${fmt.format(c.createdAt)}'
                        : '-',
              ),
            ]),
            pw.TableRow(children: [
              _metaCell('Person involved', c.personInvolved ? 'Yes' : 'No'),
              _metaCell(
                'Representative',
                c.representativeName != null
                    ? '${c.representativeName} (${c.representativeInvolved ? 'involved' : 'not involved'})'
                    : c.representativeInvolved
                        ? 'Involved'
                        : 'Not involved',
              ),
            ]),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5),
      ],
    ),
    build: (_) => [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(18),
          1: const pw.FlexColumnWidth(),
          2: const pw.FixedColumnWidth(22),
          3: const pw.FixedColumnWidth(22),
          4: const pw.FixedColumnWidth(22),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: headerColor),
            children: [
              _thCell('#'),
              _thCell('Care domain'),
              _thCell('A'),
              _thCell('B'),
              _thCell('C'),
            ],
          ),
          for (var i = 0; i < _kDomainKeys.length; i++) ...[
            pw.TableRow(children: [
              _tdNum('${i + 1}'),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(4, 3, 4, 1),
                child: pw.Text(
                  _kDomainLabels[_kDomainKeys[i]]! +
                      (_kPriorityDomains.contains(_kDomainKeys[i]) ? ' *' : ''),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              _levelCell(c.domains?[_kDomainKeys[i]]?.level, 'A'),
              _levelCell(c.domains?[_kDomainKeys[i]]?.level, 'B'),
              _levelCell(c.domains?[_kDomainKeys[i]]?.level, 'C'),
            ]),
            pw.TableRow(children: [
              pw.SizedBox(),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(4, 1, 4, 3),
                child: pw.Text(
                  c.domains?[_kDomainKeys[i]]?.evidence ??
                      'No evidence recorded.',
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: c.domains?[_kDomainKeys[i]]?.evidence != null
                        ? PdfColors.grey800
                        : PdfColors.grey500,
                    fontStyle:
                        c.domains?[_kDomainKeys[i]]?.evidence != null
                            ? pw.FontStyle.normal
                            : pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(),
              pw.SizedBox(),
              pw.SizedBox(),
            ]),
          ],
        ],
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        '* Priority domain - a single A in any of these triggers a positive outcome.',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
      ),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: outcomeColor, width: 1.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              positive
                  ? 'POSITIVE - referral for full assessment is necessary'
                  : 'NEGATIVE - no referral for full assessment is necessary',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: outcomeColor,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Totals - A: ${c.countA}   B: ${c.countB}   C: ${c.countC}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            if (c.rationale != null) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'Rationale: ${c.rationale}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ],
        ),
      ),
      if (c.isCompleted) ...[
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          children: [
            pw.TableRow(children: [
              _metaCell('Assessor', c.assessorName ?? '-'),
              _metaCell('Role', c.assessorRole ?? '-'),
            ]),
            pw.TableRow(children: [
              _metaCell('Organisation', c.assessorOrg ?? '-'),
              _metaCell(
                'Signed off',
                c.completedAt != null ? fmt.format(c.completedAt!) : '-',
              ),
            ]),
          ],
        ),
      ],
      pw.SizedBox(height: 12),
      pw.Text(
        'A positive checklist does not mean eligibility for NHS CHC - a full assessment is required. '
        'Generated by Smart Care on ${fmt.format(DateTime.now())}. Record ID ${c.id}.',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
      ),
    ],
  ));

  return doc.save();
}

pw.Widget _metaCell(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

pw.Widget _thCell(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );

pw.Widget _tdNum(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
      ),
    );

pw.Widget _levelCell(String? selected, String level) {
  final isSelected = selected == level;
  final fillColor = isSelected ? PdfColor.fromHex('0B2E33') : null;
  return pw.Center(
    child: pw.Container(
      width: 14,
      height: 14,
      decoration: pw.BoxDecoration(
        color: fillColor,
        border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: isSelected
          ? pw.Center(
              child: pw.Text(
                level,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            )
          : pw.SizedBox(),
    ),
  );
}
