import 'package:flutter/material.dart';
import '../../models/lasting_power.dart';
import '../../models/resident.dart';
import '../../services/lasting_power_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';

class LastingPowersScreen extends StatefulWidget {
  final Resident resident;
  const LastingPowersScreen({super.key, required this.resident});

  @override
  State<LastingPowersScreen> createState() => _LastingPowersScreenState();
}

class _LastingPowersScreenState extends State<LastingPowersScreen> {
  final _service = LastingPowerService();
  List<LastingPower> _records = [];
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

  Future<void> _confirmDelete(LastingPower r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete lasting power?'),
        content: Text(
          '${lpTypeLabel(r.type)} for ${r.attorneyName} will be removed.',
        ),
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
        title: Text('Lasting Powers · ${widget.resident.firstName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add LPA / power'),
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) =>
                _LpFormSheet(residentId: widget.resident.id, service: _service),
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
              icon: Icons.gavel_outlined,
              title: 'No lasting powers recorded',
              subtitle: 'Tap + to add an LPA or deputy.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: _records.length,
                itemBuilder: (_, i) {
                  final r = _records[i];
                  return _LpCard(record: r, onDelete: () => _confirmDelete(r));
                },
              ),
            ),
    );
  }
}

class _LpCard extends StatelessWidget {
  final LastingPower record;
  final VoidCallback onDelete;

  const _LpCard({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
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
                  Expanded(
                    child: Text(
                      lpTypeLabel(r.type),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (r.registered)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'Registered',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
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
              Text(
                'Attorney: ${r.attorneyName}',
                style: const TextStyle(fontSize: 14),
              ),
              if (r.attorneyContact != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Contact: ${r.attorneyContact}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
              if (r.reference != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Ref: ${r.reference}',
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

class _LpFormSheet extends StatefulWidget {
  final int residentId;
  final LastingPowerService service;

  const _LpFormSheet({required this.residentId, required this.service});

  @override
  State<_LpFormSheet> createState() => _LpFormSheetState();
}

class _LpFormSheetState extends State<_LpFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  String _type = lpTypes.first;
  bool _registered = false;
  final _attorneyName = TextEditingController();
  final _attorneyContact = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _attorneyName.dispose();
    _attorneyContact.dispose();
    _reference.dispose();
    _notes.dispose();
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
        residentId: widget.residentId,
        type: _type,
        attorneyName: _attorneyName.text.trim(),
        registered: _registered,
        attorneyContact: _attorneyContact.text.trim().isEmpty
            ? null
            : _attorneyContact.text.trim(),
        reference: _reference.text.trim().isEmpty
            ? null
            : _reference.text.trim(),
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
                    'Add LPA / power',
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
                items: lpTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(lpTypeLabel(t)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _attorneyName,
                decoration: const InputDecoration(
                  labelText: 'Attorney / deputy name *',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              SwitchListTile(
                value: _registered,
                onChanged: (v) => setState(() => _registered = v),
                title: const Text('Registered with OPG'),
                contentPadding: EdgeInsets.zero,
              ),
              TextFormField(
                controller: _attorneyContact,
                decoration: const InputDecoration(
                  labelText: 'Attorney contact',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reference,
                decoration: const InputDecoration(labelText: 'Reference'),
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
