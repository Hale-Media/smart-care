import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/resident.dart';
import '../../models/safeguarding_concern.dart';
import '../../services/safeguarding_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';

class SafeguardingScreen extends StatefulWidget {
  final Resident resident;
  const SafeguardingScreen({super.key, required this.resident});

  @override
  State<SafeguardingScreen> createState() => _SafeguardingScreenState();
}

class _SafeguardingScreenState extends State<SafeguardingScreen> {
  final _service = SafeguardingService();
  List<SafeguardingConcern> _concerns = [];
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
      final concerns = await _service.forResident(widget.resident.id);
      if (mounted) setState(() => _concerns = concerns);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusSeverity(String status) {
    switch (status) {
      case 'raised':
        return 'high';
      case 'under_review':
        return 'medium';
      case 'referred':
        return 'info';
      default:
        return 'low';
    }
  }

  Future<void> _confirmDelete(SafeguardingConcern c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete concern?'),
        content: const Text('This safeguarding concern will be removed.'),
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
        title: Text('Safeguarding · ${widget.resident.firstName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Raise concern'),
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _RaiseConcernSheet(
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
          : _concerns.isEmpty
          ? const EmptyState(
              icon: Icons.shield_outlined,
              title: 'No safeguarding concerns',
              subtitle: 'Tap + to raise a concern.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: _concerns.length,
                itemBuilder: (_, i) {
                  final c = _concerns[i];
                  return _ConcernCard(
                    concern: c,
                    statusSeverity: _statusSeverity(c.status),
                    service: _service,
                    onDelete: () => _confirmDelete(c),
                    onActioned: _load,
                  );
                },
              ),
            ),
    );
  }
}

class _ConcernCard extends StatelessWidget {
  final SafeguardingConcern concern;
  final String statusSeverity;
  final SafeguardingService service;
  final VoidCallback onDelete;
  final VoidCallback onActioned;

  const _ConcernCard({
    required this.concern,
    required this.statusSeverity,
    required this.service,
    required this.onDelete,
    required this.onActioned,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final c = concern;
    final canAct = c.status != 'closed';
    final canReview = c.status == 'raised' || c.status == 'under_review';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(label: sgCategoryLabel(c.category), severity: 'low'),
                const SizedBox(width: 6),
                StatusPill(
                  label: sgStatusLabel(c.status),
                  severity: statusSeverity,
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 18,
                    color: Colors.black54,
                  ),
                  onSelected: (action) => _handleAction(context, action),
                  itemBuilder: (_) => [
                    if (canReview)
                      const PopupMenuItem(
                        value: 'review',
                        child: Text('Review'),
                      ),
                    if (canReview)
                      const PopupMenuItem(
                        value: 'refer',
                        child: Text('Refer to LA'),
                      ),
                    if (canReview)
                      const PopupMenuItem(
                        value: 'no_referral',
                        child: Text('No referral'),
                      ),
                    if (canAct)
                      const PopupMenuItem(value: 'close', child: Text('Close')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(c.description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'Raised ${fmt.format(c.raisedAt)}'
              '${c.raisedByName != null ? ' by ${c.raisedByName}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (c.managerReview != null) ...[
              const SizedBox(height: 6),
              Text(
                'Manager review: ${c.managerReview}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    if (action == 'delete') {
      onDelete();
      return;
    }
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ActionSheet(concern: concern, action: action, service: service),
    );
    if (done == true) onActioned();
  }
}

class _RaiseConcernSheet extends StatefulWidget {
  final int residentId;
  final SafeguardingService service;

  const _RaiseConcernSheet({required this.residentId, required this.service});

  @override
  State<_RaiseConcernSheet> createState() => _RaiseConcernSheetState();
}

class _RaiseConcernSheetState extends State<_RaiseConcernSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  String _category = sgCategories.first;
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.create(
        category: _category,
        description: _description.text.trim(),
        residentId: widget.residentId,
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
                  const Expanded(
                    child: Text(
                      'Raise safeguarding concern',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Raise concern'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: sgCategories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(sgCategoryLabel(c)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description *'),
                maxLines: 4,
                minLines: 3,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
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

class _ActionSheet extends StatefulWidget {
  final SafeguardingConcern concern;
  final String action;
  final SafeguardingService service;

  const _ActionSheet({
    required this.concern,
    required this.action,
    required this.service,
  });

  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<_ActionSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  bool _cqcNotified = false;

  final _managerReview = TextEditingController();
  final _laReference = TextEditingController();
  final _outcome = TextEditingController();

  @override
  void dispose() {
    _managerReview.dispose();
    _laReference.dispose();
    _outcome.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.action) {
      case 'review':
        return 'Record manager review';
      case 'refer':
        return 'Refer to Local Authority';
      case 'no_referral':
        return 'Record no referral decision';
      case 'close':
        return 'Close concern';
      default:
        return 'Action';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final data = <String, dynamic>{};
    switch (widget.action) {
      case 'review':
      case 'no_referral':
        if (_managerReview.text.trim().isNotEmpty) {
          data['manager_review'] = _managerReview.text.trim();
        }
        break;
      case 'refer':
        if (_laReference.text.trim().isNotEmpty) {
          data['la_reference'] = _laReference.text.trim();
        }
        if (_cqcNotified) data['cqc_notified'] = true;
        break;
      case 'close':
        if (_outcome.text.trim().isNotEmpty) {
          data['outcome'] = _outcome.text.trim();
        }
        break;
    }

    try {
      await widget.service.action(widget.concern.id, widget.action, data);
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
                      _title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
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
              if (widget.action == 'review' ||
                  widget.action == 'no_referral') ...[
                TextFormField(
                  controller: _managerReview,
                  decoration: const InputDecoration(
                    labelText: 'Manager review notes',
                  ),
                  maxLines: 4,
                  minLines: 3,
                ),
              ],
              if (widget.action == 'refer') ...[
                TextFormField(
                  controller: _laReference,
                  decoration: const InputDecoration(
                    labelText: 'LA reference number',
                  ),
                ),
                SwitchListTile(
                  value: _cqcNotified,
                  onChanged: (v) => setState(() => _cqcNotified = v),
                  title: const Text('CQC notified'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (widget.action == 'close') ...[
                TextFormField(
                  controller: _outcome,
                  decoration: const InputDecoration(labelText: 'Outcome'),
                  maxLines: 4,
                  minLines: 3,
                ),
              ],
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
