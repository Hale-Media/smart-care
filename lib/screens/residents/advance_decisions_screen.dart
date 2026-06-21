import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/advance_decision.dart';
import '../../models/resident.dart';
import '../../services/advance_decision_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';

class AdvanceDecisionsScreen extends StatefulWidget {
  final Resident resident;
  const AdvanceDecisionsScreen({super.key, required this.resident});

  @override
  State<AdvanceDecisionsScreen> createState() => _AdvanceDecisionsScreenState();
}

class _AdvanceDecisionsScreenState extends State<AdvanceDecisionsScreen> {
  final _service = AdvanceDecisionService();
  List<AdvanceDecision> _records = [];
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

  Future<void> _confirmDelete(AdvanceDecision r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete advance decision?'),
        content: Text('${adTypeLabel(r.type)} record will be removed.'),
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
        title: Text('Advance Decisions · ${widget.resident.firstName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add advance decision'),
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) =>
                _AdFormSheet(residentId: widget.resident.id, service: _service),
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
              icon: Icons.do_not_disturb_on_outlined,
              title: 'No advance decisions recorded',
              subtitle: 'Tap + to add a DNACPR, ReSPECT or ADRT.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: _records.length,
                itemBuilder: (_, i) {
                  final r = _records[i];
                  return _AdCard(record: r, onDelete: () => _confirmDelete(r));
                },
              ),
            ),
    );
  }
}

class _AdCard extends StatelessWidget {
  final AdvanceDecision record;
  final VoidCallback onDelete;

  const _AdCard({required this.record, required this.onDelete});

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
                  Text(
                    adTypeLabel(r.type),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(
                    label: r.inPlace ? 'In place' : 'Not in place',
                    severity: r.inPlace ? 'info' : 'low',
                  ),
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
              if (r.formReference != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Form ref: ${r.formReference}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              if (r.completedBy != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Completed by: ${r.completedBy}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
              if (r.dateCompleted != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Date: ${fmt.format(r.dateCompleted!)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (r.reviewDate != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Review: ${fmt.format(r.reviewDate!)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (r.location != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Location: ${r.location}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
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

class _AdFormSheet extends StatefulWidget {
  final int residentId;
  final AdvanceDecisionService service;

  const _AdFormSheet({required this.residentId, required this.service});

  @override
  State<_AdFormSheet> createState() => _AdFormSheetState();
}

class _AdFormSheetState extends State<_AdFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  String _type = adTypes.first;
  bool _inPlace = true;
  final _formReference = TextEditingController();
  final _completedBy = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();

  DateTime? _dateCompleted;
  DateTime? _reviewDate;
  final _dateCompletedCtrl = TextEditingController();
  final _reviewDateCtrl = TextEditingController();

  @override
  void dispose() {
    _formReference.dispose();
    _completedBy.dispose();
    _location.dispose();
    _notes.dispose();
    _dateCompletedCtrl.dispose();
    _reviewDateCtrl.dispose();
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
        type: _type,
        inPlace: _inPlace,
        formReference: _formReference.text.trim().isEmpty
            ? null
            : _formReference.text.trim(),
        completedBy: _completedBy.text.trim().isEmpty
            ? null
            : _completedBy.text.trim(),
        dateCompleted: _dateCompleted != null
            ? DateFormat('yyyy-MM-dd').format(_dateCompleted!)
            : null,
        reviewDate: _reviewDate != null
            ? DateFormat('yyyy-MM-dd').format(_reviewDate!)
            : null,
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
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
                    'Add advance decision',
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
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: adTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(adTypeLabel(t)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              SwitchListTile(
                value: _inPlace,
                onChanged: (v) => setState(() => _inPlace = v),
                title: const Text('In place'),
                contentPadding: EdgeInsets.zero,
              ),
              TextFormField(
                controller: _formReference,
                decoration: const InputDecoration(labelText: 'Form reference'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _completedBy,
                decoration: const InputDecoration(labelText: 'Completed by'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateCompletedCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date completed',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDate(
                      _dateCompletedCtrl,
                      (d) => _dateCompleted = d,
                    ),
                  ),
                ),
                onTap: () =>
                    _pickDate(_dateCompletedCtrl, (d) => _dateCompleted = d),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reviewDateCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Review date',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () =>
                        _pickDate(_reviewDateCtrl, (d) => _reviewDate = d),
                  ),
                ),
                onTap: () => _pickDate(_reviewDateCtrl, (d) => _reviewDate = d),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location'),
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
