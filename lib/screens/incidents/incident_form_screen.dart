import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/incident.dart';
import '../../models/resident.dart';
import '../../providers/auth_provider.dart';
import '../../services/incident_service.dart';
import '../../utils/validators.dart';

/// Structured incident / accident report supporting CQC + safeguarding flags.
class IncidentFormScreen extends StatefulWidget {
  final Resident resident;
  const IncidentFormScreen({super.key, required this.resident});
  @override
  State<IncidentFormScreen> createState() => _IncidentFormScreenState();
}

class _IncidentFormScreenState extends State<IncidentFormScreen> {
  final _service = IncidentService();
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _action = TextEditingController();
  final _location = TextEditingController();
  final _injuryDetails = TextEditingController();
  String _category = 'fall';
  String _severity = 'minor';
  bool _injury = false;
  bool _witnessed = false;
  bool _familyNotified = false;
  bool _gpNotified = false;
  bool _safeguarding = false;
  bool _cqc = false;
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final staffId = context.read<AuthProvider>().user?.id ?? 0;
    final now = DateTime.now();
    final i = Incident(
      id: 0,
      residentId: widget.resident.id,
      category: _category,
      severity: _severity,
      occurredAt: now,
      reportedAt: now,
      reportedByStaffId: staffId,
      location: _location.text.trim(),
      description: _description.text.trim(),
      immediateAction: _action.text.trim(),
      injurySustained: _injury,
      injuryDetails: _injury ? _injuryDetails.text.trim() : null,
      witnessed: _witnessed,
      familyNotified: _familyNotified,
      gpNotified: _gpNotified,
      safeguardingRaised: _safeguarding,
      cqcNotifiable: _cqc,
    );
    try {
      await _service.create(i);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _action.dispose();
    _location.dispose();
    _injuryDetails.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Incident · ${widget.resident.firstName}')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Log incident'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                'fall',
                'injury',
                'medication_error',
                'safeguarding',
                'behaviour',
                'near_miss',
                'other'
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: const ['minor', 'moderate', 'major', 'catastrophic']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _severity = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'What happened?'),
              maxLines: 4,
              validator: (v) => Validators.required(v, 'Description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _action,
              decoration:
                  const InputDecoration(labelText: 'Immediate action taken'),
              maxLines: 3,
            ),
            SwitchListTile(
              value: _injury,
              onChanged: (v) => setState(() => _injury = v),
              title: const Text('Injury sustained'),
            ),
            if (_injury) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _injuryDetails,
                decoration: const InputDecoration(labelText: 'Injury details'),
                maxLines: 3,
              ),
              const SizedBox(height: 4),
            ],
            SwitchListTile(
              value: _witnessed,
              onChanged: (v) => setState(() => _witnessed = v),
              title: const Text('Witnessed'),
            ),
            SwitchListTile(
              value: _familyNotified,
              onChanged: (v) => setState(() => _familyNotified = v),
              title: const Text('Family / next of kin notified'),
            ),
            SwitchListTile(
              value: _gpNotified,
              onChanged: (v) => setState(() => _gpNotified = v),
              title: const Text('GP notified'),
            ),
            SwitchListTile(
              value: _safeguarding,
              onChanged: (v) => setState(() => _safeguarding = v),
              title: const Text('Safeguarding referral raised'),
            ),
            SwitchListTile(
              value: _cqc,
              onChanged: (v) => setState(() => _cqc = v),
              title: const Text('CQC notifiable'),
            ),
          ],
        ),
      ),
    );
  }
}
