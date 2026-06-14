import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/resident.dart';
import '../../models/vital_reading.dart';
import '../../providers/auth_provider.dart';
import '../../services/vitals_service.dart';

class VitalsFormScreen extends StatefulWidget {
  final Resident resident;
  const VitalsFormScreen({super.key, required this.resident});
  @override
  State<VitalsFormScreen> createState() => _VitalsFormScreenState();
}

class _VitalsFormScreenState extends State<VitalsFormScreen> {
  final _service = VitalsService();
  final _rr = TextEditingController();
  final _spo2 = TextEditingController();
  final _temp = TextEditingController();
  final _bp = TextEditingController();
  final _hr = TextEditingController();
  final _glucose = TextEditingController();
  final _notes = TextEditingController();
  bool _onOxygen = false;
  String _consciousness = 'A';
  bool _saving = false;

  int? _i(TextEditingController c) => int.tryParse(c.text.trim());
  double? _d(TextEditingController c) => double.tryParse(c.text.trim());

  Future<void> _save() async {
    setState(() => _saving = true);
    final staffId = context.read<AuthProvider>().user?.id ?? 0;
    final v = VitalReading(
      id: 0,
      residentId: widget.resident.id,
      recordedAt: DateTime.now(),
      recordedByStaffId: staffId,
      respiratoryRate: _i(_rr),
      spo2: _i(_spo2),
      onOxygen: _onOxygen,
      temperature: _d(_temp),
      systolicBp: _i(_bp),
      heartRate: _i(_hr),
      consciousness: _consciousness,
      bloodGlucose: _d(_glucose),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    try {
      await _service.record(v);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record vitals')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _num(_rr, 'Respiratory rate (breaths/min)'),
          _num(_spo2, 'SpO₂ (%)'),
          SwitchListTile(
            value: _onOxygen,
            onChanged: (v) => setState(() => _onOxygen = v),
            title: const Text('On supplemental oxygen'),
          ),
          _num(_temp, 'Temperature (°C)'),
          _num(_bp, 'Systolic BP (mmHg)'),
          _num(_hr, 'Heart rate (bpm)'),
          _num(_glucose, 'Blood glucose (mmol/L) — optional'),
          DropdownButtonFormField<String>(
            initialValue: _consciousness,
            decoration:
                const InputDecoration(labelText: 'Consciousness (ACVPU)'),
            items: const ['A', 'C', 'V', 'P', 'U']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _consciousness = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save vitals'),
          ),
        ],
      ),
    );
  }

  Widget _num(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
        ),
      );
}
