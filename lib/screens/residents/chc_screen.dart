// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/chc_checklist.dart';
import '../../models/resident.dart';
import '../../services/chc_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';

// The 11 CHC domains in order, mirroring the backend CHC_DOMAINS constant.
// Priority domains (single A triggers referral) are marked true.
const _domains = {
  'breathing': (label: 'Breathing', priority: true),
  'nutrition': (label: 'Nutrition', priority: false),
  'continence': (label: 'Continence', priority: false),
  'skin': (label: 'Skin', priority: false),
  'mobility': (label: 'Mobility', priority: false),
  'communication': (label: 'Communication', priority: false),
  'psychological': (label: 'Psychological & emotional needs', priority: false),
  'cognition': (label: 'Cognition', priority: false),
  'behaviour': (label: 'Behaviour', priority: true),
  'drug_therapies': (label: 'Drug therapies & medication', priority: true),
  'altered_consciousness': (
    label: 'Altered states of consciousness',
    priority: true,
  ),
};

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
      final list = await _service.forResident(widget.resident.id);
      if (mounted) setState(() => _checklists = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({ChcChecklist? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ChcFormPage(
          residentId: widget.resident.id,
          service: _service,
          existing: existing,
        ),
      ),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _confirmDelete(ChcChecklist c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete checklist?'),
        content: const Text('This draft will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _signOff(ChcChecklist c) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _SignOffDialog(),
    );
    if (result == null) return;
    try {
      await _service.complete(
        c.id,
        assessorName: result['name']!,
        assessorRole: result['role'],
        assessorOrg: result['org'],
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Checklist signed off')));
        _load();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CHC · ${widget.resident.firstName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New checklist'),
        onPressed: () => _openForm(),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : _checklists.isEmpty
          ? const EmptyState(
              icon: Icons.health_and_safety_outlined,
              title: 'No CHC checklists',
              subtitle: 'Tap + to start a new NHS CHC checklist.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: _checklists.length,
                itemBuilder: (_, i) {
                  final c = _checklists[i];
                  return _ChecklistCard(
                    checklist: c,
                    onEdit: c.isCompleted ? null : () => _openForm(existing: c),
                    onDelete: c.isCompleted ? null : () => _confirmDelete(c),
                    onSignOff: c.isCompleted ? null : () => _signOff(c),
                  );
                },
              ),
            ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final ChcChecklist checklist;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSignOff;

  const _ChecklistCard({
    required this.checklist,
    this.onEdit,
    this.onDelete,
    this.onSignOff,
  });

  @override
  Widget build(BuildContext context) {
    final c = checklist;
    final fmt = DateFormat('d MMM yyyy');
    final outcomeSeverity = c.isPositive ? 'high' : 'ok';
    final outcomeLabel = c.isPositive ? 'Positive — refer' : 'Negative';

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
                    fmt.format(c.createdAt),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                StatusPill(
                  label: c.isCompleted ? 'Signed off' : 'Draft',
                  severity: c.isCompleted ? 'ok' : 'medium',
                ),
                const SizedBox(width: 6),
                StatusPill(label: outcomeLabel, severity: outcomeSeverity),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _DomainCount('A', c.countA, AppTheme.critical),
                const SizedBox(width: 12),
                _DomainCount('B', c.countB, AppTheme.warning),
                const SizedBox(width: 12),
                _DomainCount('C', c.countC, Colors.green),
              ],
            ),
            if (c.assessorName != null) ...[
              const SizedBox(height: 6),
              Text(
                'Signed off by ${c.assessorName}'
                '${c.assessorRole != null ? ' · ${c.assessorRole}' : ''}'
                '${c.completedAt != null ? ' on ${fmt.format(c.completedAt!)}' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (!c.isCompleted) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onDelete != null)
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
                  const SizedBox(width: 8),
                  if (onEdit != null)
                    TextButton(onPressed: onEdit, child: const Text('Edit')),
                  const SizedBox(width: 6),
                  if (onSignOff != null)
                    FilledButton(
                      onPressed: onSignOff,
                      child: const Text('Sign off'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DomainCount extends StatelessWidget {
  final String level;
  final int count;
  final Color color;
  const _DomainCount(this.level, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            level,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('$count', style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

// ── CHC form page (create / edit draft) ───────────────────────────────────────

class _ChcFormPage extends StatefulWidget {
  final int residentId;
  final ChcService service;
  final ChcChecklist? existing;

  const _ChcFormPage({
    required this.residentId,
    required this.service,
    this.existing,
  });

  @override
  State<_ChcFormPage> createState() => _ChcFormPageState();
}

class _ChcFormPageState extends State<_ChcFormPage> {
  // Domain state: key → {level, evidence controller}
  final Map<String, String> _levels = {};
  final Map<String, TextEditingController> _evidenceCtrl = {};
  final _rationaleCtrl = TextEditingController();
  bool _personInvolved = false;
  bool _repInvolved = false;
  final _repNameCtrl = TextEditingController();
  bool _saving = false;

  // Derived outcome (mirrors backend logic)
  String get _outcome {
    int a = 0, b = 0;
    bool priorityA = false;
    for (final key in _domains.keys) {
      final lvl = _levels[key] ?? 'C';
      if (lvl == 'A') {
        a++;
        if (_domains[key]!.priority) priorityA = true;
      } else if (lvl == 'B') {
        b++;
      }
    }
    final positive = a >= 2 || b >= 5 || (a >= 1 && b >= 4) || priorityA;
    return positive ? 'positive' : 'negative';
  }

  @override
  void initState() {
    super.initState();
    for (final key in _domains.keys) {
      final existing = widget.existing?.domains?[key];
      _levels[key] = existing?.level ?? 'C';
      _evidenceCtrl[key] = TextEditingController(
        text: existing?.evidence ?? '',
      );
    }
    if (widget.existing != null) {
      _rationaleCtrl.text = widget.existing!.rationale ?? '';
      _personInvolved = widget.existing!.personInvolved;
      _repInvolved = widget.existing!.representativeInvolved;
      _repNameCtrl.text = widget.existing!.representativeName ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in _evidenceCtrl.values) {
      c.dispose();
    }
    _rationaleCtrl.dispose();
    _repNameCtrl.dispose();
    super.dispose();
  }

  Map<String, Map<String, String?>> _buildDomains() {
    final result = <String, Map<String, String?>>{};
    for (final key in _domains.keys) {
      result[key] = {
        'level': _levels[key] ?? 'C',
        'evidence': _evidenceCtrl[key]!.text.trim().isEmpty
            ? null
            : _evidenceCtrl[key]!.text.trim(),
      };
    }
    return result;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final domains = _buildDomains();
      if (widget.existing != null) {
        await widget.service.update(
          widget.existing!.id,
          domains: domains,
          rationale: _rationaleCtrl.text.trim(),
          personInvolved: _personInvolved,
          representativeName: _repNameCtrl.text.trim(),
          representativeInvolved: _repInvolved,
        );
      } else {
        await widget.service.create(
          residentId: widget.residentId,
          domains: domains,
          rationale: _rationaleCtrl.text.trim(),
          personInvolved: _personInvolved,
          representativeName: _repNameCtrl.text.trim(),
          representativeInvolved: _repInvolved,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final outcome = _outcome;
    final isPositive = outcome == 'positive';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit CHC checklist' : 'New CHC checklist'),
      ),
      body: Column(
        children: [
          // Live outcome banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: isPositive
                ? AppTheme.critical.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isPositive
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: isPositive ? AppTheme.critical : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isPositive
                      ? 'Outcome: POSITIVE — referral indicated'
                      : 'Outcome: Negative',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isPositive ? AppTheme.critical : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const Text(
                  'Score each domain A, B or C. A = most severe needs.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...(_domains.entries.map(
                  (e) => _DomainRow(
                    domainKey: e.key,
                    label: e.value.label,
                    isPriority: e.value.priority,
                    level: _levels[e.key] ?? 'C',
                    evidenceCtrl: _evidenceCtrl[e.key]!,
                    onLevelChanged: (v) => setState(() => _levels[e.key] = v),
                  ),
                )),
                const Divider(height: 32),
                TextField(
                  controller: _rationaleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rationale (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _personInvolved,
                  onChanged: (v) => setState(() => _personInvolved = v),
                  title: const Text('Person / resident involved in assessment'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _repInvolved,
                  onChanged: (v) => setState(() => _repInvolved = v),
                  title: const Text('Representative involved'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_repInvolved) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _repNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Representative name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  _saving
                      ? 'Saving…'
                      : isEdit
                      ? 'Save changes'
                      : 'Save draft',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DomainRow extends StatelessWidget {
  final String domainKey;
  final String label;
  final bool isPriority;
  final String level;
  final TextEditingController evidenceCtrl;
  final ValueChanged<String> onLevelChanged;

  const _DomainRow({
    required this.domainKey,
    required this.label,
    required this.isPriority,
    required this.level,
    required this.evidenceCtrl,
    required this.onLevelChanged,
  });

  Color _colorFor(String l) => switch (l) {
    'A' => AppTheme.critical,
    'B' => AppTheme.warning,
    _ => Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isPriority)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.critical.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Priority',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.critical,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: ['A', 'B', 'C']
                .map(
                  (l) => ButtonSegment(
                    value: l,
                    label: Text(
                      l,
                      style: TextStyle(
                        color: _colorFor(l),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
                .toList(),
            selected: {level},
            onSelectionChanged: (s) => onLevelChanged(s.first),
            style: ButtonStyle(
              iconColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _colorFor(level)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: evidenceCtrl,
            decoration: const InputDecoration(
              hintText: 'Evidence (optional)',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
            maxLines: 2,
            minLines: 1,
          ),
        ],
      ),
    );
  }
}

// ── Sign-off dialog ───────────────────────────────────────────────────────────

class _SignOffDialog extends StatefulWidget {
  const _SignOffDialog();

  @override
  State<_SignOffDialog> createState() => _SignOffDialogState();
}

class _SignOffDialogState extends State<_SignOffDialog> {
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _orgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign off checklist'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Assessor name *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _roleCtrl,
              decoration: const InputDecoration(labelText: 'Role (optional)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _orgCtrl,
              decoration: const InputDecoration(
                labelText: 'Organisation (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name': _nameCtrl.text.trim(),
                'role': _roleCtrl.text.trim(),
                'org': _orgCtrl.text.trim(),
              });
            }
          },
          child: const Text('Sign off'),
        ),
      ],
    );
  }
}
