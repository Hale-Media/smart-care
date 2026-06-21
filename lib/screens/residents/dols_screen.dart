import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dols_authorisation.dart';
import '../../models/resident.dart';
import '../../services/dols_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';

class DoLsScreen extends StatefulWidget {
  final Resident resident;
  const DoLsScreen({super.key, required this.resident});

  @override
  State<DoLsScreen> createState() => _DoLsScreenState();
}

class _DoLsScreenState extends State<DoLsScreen> {
  final _service = DoLsService();
  List<DoLsAuthorisation> _records = [];
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
      final records = await _service.forResident(widget.resident.id);
      if (mounted) setState(() => _records = records);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusSeverity(String status) {
    switch (status) {
      case 'granted':
        return 'info';
      case 'declined':
      case 'expired':
      case 'ended':
        return 'medium';
      case 'applied':
      case 'urgent':
        return 'high';
      default:
        return 'low';
    }
  }

  Future<void> _confirmDelete(DoLsAuthorisation r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete DoLS record?'),
        content: const Text('This record will be removed.'),
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
        await _service.delete(r.id);
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
        title: Text('DoLS · ${widget.resident.firstName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add DoLS record'),
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _DoLsFormSheet(
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
          : _records.isEmpty
          ? const EmptyState(
              icon: Icons.lock_outlined,
              title: 'No DoLS records',
              subtitle: 'Tap + to add the first one.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: _records.length,
                itemBuilder: (_, i) {
                  final r = _records[i];
                  return _DoLsCard(
                    record: r,
                    statusSeverity: _statusSeverity(r.status),
                    onDelete: () => _confirmDelete(r),
                  );
                },
              ),
            ),
    );
  }
}

class _DoLsCard extends StatelessWidget {
  final DoLsAuthorisation record;
  final String statusSeverity;
  final VoidCallback onDelete;

  const _DoLsCard({
    required this.record,
    required this.statusSeverity,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final r = record;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(
                    label: doLsStatusLabel(r.status),
                    severity: statusSeverity,
                  ),
                  if (r.urgent) ...[
                    const SizedBox(width: 6),
                    const StatusPill(label: 'Urgent', severity: 'high'),
                  ],
                  if (r.isExpiringSoon) ...[
                    const SizedBox(width: 6),
                    const StatusPill(label: 'Expiring soon', severity: 'high'),
                  ],
                  const Spacer(),
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
              if (r.reference != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Ref: ${r.reference}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
              if (r.supervisoryBody != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Supervisory body: ${r.supervisoryBody}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              const SizedBox(height: 6),
              if (r.appliedOn != null)
                _DateRow('Applied', fmt.format(r.appliedOn!)),
              if (r.grantedOn != null)
                _DateRow('Granted', fmt.format(r.grantedOn!)),
              if (r.expiresOn != null)
                _DateRow('Expires', fmt.format(r.expiresOn!)),
              if (r.conditions != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Conditions: ${r.conditions}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              if (r.notes != null) ...[
                const SizedBox(height: 4),
                Text(
                  r.notes!,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  const _DateRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _DoLsFormSheet extends StatefulWidget {
  final int residentId;
  final DoLsService service;

  const _DoLsFormSheet({required this.residentId, required this.service});

  @override
  State<_DoLsFormSheet> createState() => _DoLsFormSheetState();
}

class _DoLsFormSheetState extends State<_DoLsFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  String _status = doLsStatuses.first;
  bool _urgent = false;
  final _reference = TextEditingController();
  final _supervisoryBody = TextEditingController();
  final _conditions = TextEditingController();
  final _notes = TextEditingController();

  DateTime? _appliedOn;
  DateTime? _grantedOn;
  DateTime? _expiresOn;
  final _appliedCtrl = TextEditingController();
  final _grantedCtrl = TextEditingController();
  final _expiresCtrl = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
    _supervisoryBody.dispose();
    _conditions.dispose();
    _notes.dispose();
    _appliedCtrl.dispose();
    _grantedCtrl.dispose();
    _expiresCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    TextEditingController ctrl,
    void Function(DateTime) onPicked,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        ctrl.text = DateFormat('d MMM yyyy').format(picked);
        onPicked(picked);
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
        status: _status,
        urgent: _urgent,
        reference: _reference.text.trim().isEmpty
            ? null
            : _reference.text.trim(),
        supervisoryBody: _supervisoryBody.text.trim().isEmpty
            ? null
            : _supervisoryBody.text.trim(),
        appliedOn: _appliedOn != null
            ? DateFormat('yyyy-MM-dd').format(_appliedOn!)
            : null,
        grantedOn: _grantedOn != null
            ? DateFormat('yyyy-MM-dd').format(_grantedOn!)
            : null,
        expiresOn: _expiresOn != null
            ? DateFormat('yyyy-MM-dd').format(_expiresOn!)
            : null,
        conditions: _conditions.text.trim().isEmpty
            ? null
            : _conditions.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
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
                  const Text(
                    'Add DoLS record',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: doLsStatuses
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(doLsStatusLabel(s)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              SwitchListTile(
                value: _urgent,
                onChanged: (v) => setState(() => _urgent = v),
                title: const Text('Urgent authorisation'),
                contentPadding: EdgeInsets.zero,
              ),
              TextFormField(
                controller: _reference,
                decoration: const InputDecoration(labelText: 'Reference'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supervisoryBody,
                decoration: const InputDecoration(
                  labelText: 'Supervisory body',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _appliedCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Applied on',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () =>
                        _pickDate(_appliedCtrl, (d) => _appliedOn = d),
                  ),
                ),
                onTap: () => _pickDate(_appliedCtrl, (d) => _appliedOn = d),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _grantedCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Granted on',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () =>
                        _pickDate(_grantedCtrl, (d) => _grantedOn = d),
                  ),
                ),
                onTap: () => _pickDate(_grantedCtrl, (d) => _grantedOn = d),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _expiresCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Expires on',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () =>
                        _pickDate(_expiresCtrl, (d) => _expiresOn = d),
                  ),
                ),
                onTap: () => _pickDate(_expiresCtrl, (d) => _expiresOn = d),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _conditions,
                decoration: const InputDecoration(labelText: 'Conditions'),
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
                minLines: 2,
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
