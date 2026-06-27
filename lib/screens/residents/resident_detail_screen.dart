import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/due_medication.dart';
import '../../models/resident.dart';
import '../../providers/resident_provider.dart';
import '../../services/medication_service.dart';
import '../../services/resident_service.dart';
import '../../utils/labels.dart';
import '../../utils/validators.dart';
import '../../widgets/common/status_pill.dart';
import '../vitals/vitals_screen.dart';
import '../medication/medication_screen.dart';
import '../incidents/incident_form_screen.dart';
import '../incidents/incidents_screen.dart';
import 'advance_decisions_screen.dart';
import 'chc_screen.dart';
import 'capacity_assessments_screen.dart';
import 'care_plan_screen.dart';
import 'dols_screen.dart';
import 'home_care_calls_screen.dart';
import 'lasting_powers_screen.dart';
import 'risk_assessment_screen.dart';
import 'chc_screen.dart';
import 'safeguarding_screen.dart';
import 'visit_history_screen.dart';

/// Shows a resident profile, or an editable form when adding/editing.
/// Pass [forHomeId] when creating a resident for a specific home (bypasses
/// the global ResidentProvider and saves directly via the service).
class ResidentDetailScreen extends StatefulWidget {
  final Resident? resident;
  final int? forHomeId;
  final String? initialCareLevel;
  const ResidentDetailScreen({
    super.key,
    this.resident,
    this.forHomeId,
    this.initialCareLevel,
  });

  @override
  State<ResidentDetailScreen> createState() => _ResidentDetailScreenState();
}

class _ResidentDetailScreenState extends State<ResidentDetailScreen> {
  late bool _editing = widget.resident == null;
  Resident? _savedResident; // holds result after creating a new resident
  final _formKey = GlobalKey<FormState>();

  late final _first = TextEditingController(
    text: widget.resident?.firstName ?? '',
  );
  late final _last = TextEditingController(
    text: widget.resident?.lastName ?? '',
  );
  late final _room = TextEditingController(
    text: widget.resident?.roomNumber ?? '',
  );
  late final _nhs = TextEditingController(
    text: widget.resident?.nhsNumber ?? '',
  );
  late List<String> _conditions = List.from(widget.resident?.conditions ?? []);
  late List<String> _allergies = List.from(widget.resident?.allergies ?? []);
  late List<String> _monitoringMethods = List.from(
    widget.resident?.monitoringMethods ?? const [],
  );

  // Pending-text controllers for each tag field, so _save() can flush
  // anything typed but not yet committed as a chip.
  final _conditionsInput = TextEditingController();
  final _allergiesInput = TextEditingController();
  late final _gp = TextEditingController(text: widget.resident?.gpName ?? '');
  late final _nextOfKin = TextEditingController(
    text: widget.resident?.nextOfKin ?? '',
  );
  late final _nextOfKinPhone = TextEditingController(
    text: widget.resident?.nextOfKinPhone ?? '',
  );
  late final _consentRepresentative = TextEditingController(
    text: widget.resident?.consentRepresentative ?? '',
  );
  late final _dob = TextEditingController(
    text: widget.resident?.dob != null
        ? DateFormat('d MMM yyyy').format(widget.resident!.dob!)
        : '',
  );
  late DateTime? _dobDate = widget.resident?.dob;
  late final _consentRecordedAt = TextEditingController(
    text: widget.resident?.consentRecordedAt != null
        ? DateFormat('d MMM yyyy').format(widget.resident!.consentRecordedAt!)
        : '',
  );
  late DateTime? _consentRecordedDate = widget.resident?.consentRecordedAt;
  late final _outcomeReview = TextEditingController(
    text: widget.resident?.outcomeReviewDate != null
        ? DateFormat('d MMM yyyy').format(widget.resident!.outcomeReviewDate!)
        : '',
  );
  late DateTime? _outcomeReviewDate = widget.resident?.outcomeReviewDate;
  late String _careLevel =
      widget.resident?.careLevel ?? widget.initialCareLevel ?? 'residential';
  late final _address = TextEditingController(
    text: widget.resident?.address ?? '',
  );
  late String _callFrequency = widget.resident?.callFrequency ?? 'daily';
  late final List<String> _callTimes = List.from(
    widget.resident?.callTimes ?? [],
  );
  late String _fallRisk = widget.resident?.fallRisk ?? 'low';
  late String _nutritionRisk = widget.resident?.nutritionRisk ?? 'low';
  late String _mobility = widget.resident?.mobility ?? 'independent';
  late bool _dnacpr = widget.resident?.dnacpr ?? false;
  late String _monitoringConsent =
      widget.resident?.monitoringConsent ?? 'not_required';

  static const _monitoringOptions = [
    'direct_observation',
    'digital_care_plan',
    'movement_sensor',
    'acoustic_monitor',
    'fall_detector',
    'camera',
    'wearable',
  ];

  Future<void> _pickCallTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (!_callTimes.contains(formatted)) {
        setState(
          () => _callTimes
            ..add(formatted)
            ..sort(),
        );
      }
    }
  }

  Future<void> _pickDob() async {
    final picked = await _pickDate(
      initialDate: _dobDate ?? DateTime(1940),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobDate = picked;
        _dob.text = DateFormat('d MMM yyyy').format(picked);
      });
    }
  }

  Future<DateTime?> _pickDate({
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _room.dispose();
    _nhs.dispose();
    _address.dispose();
    _conditionsInput.dispose();
    _allergiesInput.dispose();
    _gp.dispose();
    _nextOfKin.dispose();
    _nextOfKinPhone.dispose();
    _consentRepresentative.dispose();
    _dob.dispose();
    _consentRecordedAt.dispose();
    _outcomeReview.dispose();
    super.dispose();
  }

  // Merge any text still typed (but not chip-committed) into the tag list.
  List<String> _flushTags(TextEditingController input, List<String> chips) {
    final text = input.text.trim();
    if (text.isEmpty) return chips;
    final merged = List<String>.from(chips);
    for (final part in text.split(',')) {
      final t = part.trim();
      if (t.isNotEmpty && !merged.contains(t)) merged.add(t);
    }
    return merged;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final r = Resident(
      id: widget.resident?.id ?? 0,
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      roomNumber: _room.text.trim(),
      nhsNumber: _nhs.text.trim(),
      careLevel: _careLevel,
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      callFrequency: _callFrequency,
      callTimes: _callTimes,
      fallRisk: _fallRisk,
      mobility: _mobility,
      dnacpr: _dnacpr,
      dob: _dobDate,
      conditions: _flushTags(_conditionsInput, _conditions),
      allergies: _flushTags(_allergiesInput, _allergies),
      medications: widget.resident?.medications ?? [],
      monitoringMethods: _monitoringMethods,
      nutritionRisk: _nutritionRisk,
      monitoringConsent: _monitoringConsent,
      consentRepresentative: _consentRepresentative.text.trim().isEmpty
          ? null
          : _consentRepresentative.text.trim(),
      consentRecordedAt: _consentRecordedDate,
      outcomeReviewDate: _outcomeReviewDate,
      gpName: _gp.text.trim().isEmpty ? null : _gp.text.trim(),
      nextOfKin: _nextOfKin.text.trim().isEmpty ? null : _nextOfKin.text.trim(),
      nextOfKinPhone: _nextOfKinPhone.text.trim().isEmpty
          ? null
          : _nextOfKinPhone.text.trim(),
      homeId: widget.forHomeId,
    );

    // When creating for a specific home, bypass the global provider so the
    // active-home resident list on the dashboard isn't polluted.
    if (widget.forHomeId != null && widget.resident == null) {
      try {
        await ResidentService().save(r);
        if (mounted) Navigator.of(context).pop(true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
      return;
    }

    final saved = await context.read<ResidentProvider>().save(r);
    if (!mounted) return;
    if (saved != null) {
      setState(() { _editing = false; _savedResident = saved; });
    } else {
      final err = context.read<ResidentProvider>().error ?? 'Failed to save';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _savedResident ?? widget.resident;
    return Scaffold(
      appBar: AppBar(
        title: Text(r == null ? 'Add resident' : r.fullName),
        actions: [
          if (r != null && !_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: _editing ? _form() : _profile(r!),
    );
  }

  Widget _form() {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                TextFormField(
                  controller: _first,
                  decoration: const InputDecoration(labelText: 'First name'),
                  validator: (v) => Validators.required(v, 'First name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _last,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  validator: (v) => Validators.required(v, 'Last name'),
                ),
                const SizedBox(height: 12),
                _dropdown(
                  'Care level',
                  _careLevel,
                  const [
                    'residential',
                    'nursing',
                    'dementia',
                    'respite',
                    'palliative',
                    'home_care',
                  ],
                  (v) => setState(() => _careLevel = v),
                  labelFor: Labels.careLevel,
                ),
                const SizedBox(height: 12),
                if (_careLevel == 'home_care')
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Home address',
                      prefixIcon: Icon(Icons.home_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    minLines: 2,
                    textCapitalization: TextCapitalization.words,
                  )
                else
                  TextFormField(
                    controller: _room,
                    decoration: const InputDecoration(labelText: 'Room number'),
                  ),
                if (_careLevel == 'home_care') ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Visit schedule',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'daily', label: Text('Daily')),
                      ButtonSegment(value: 'weekly', label: Text('Weekly')),
                    ],
                    selected: {_callFrequency},
                    onSelectionChanged: (s) =>
                        setState(() => _callFrequency = s.first),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Visit times (${_callFrequency == 'daily' ? 'repeats every day' : 'once each per week'})',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add time'),
                        onPressed: _pickCallTime,
                      ),
                    ],
                  ),
                  if (_callTimes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No visit times set.',
                        style: TextStyle(color: Colors.black38, fontSize: 13),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _callTimes
                          .map(
                            (t) => Chip(
                              label: Text(
                                t,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () =>
                                  setState(() => _callTimes.remove(t)),
                            ),
                          )
                          .toList(),
                    ),
                  const Divider(),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nhs,
                  decoration: const InputDecoration(labelText: 'NHS number'),
                  validator: Validators.nhsNumber,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dob,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date of birth',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _pickDob,
                    ),
                  ),
                  onTap: _pickDob,
                ),
                const SizedBox(height: 12),
                _TagsField(
                  label: 'Conditions',
                  hint: 'e.g. dementia, diabetes, COPD',
                  tags: _conditions,
                  inputController: _conditionsInput,
                  onChanged: (v) => setState(() => _conditions = v),
                ),
                const SizedBox(height: 12),
                _TagsField(
                  label: 'Allergies',
                  hint: 'e.g. penicillin, latex',
                  tags: _allergies,
                  inputController: _allergiesInput,
                  chipColor: AppTheme.critical,
                  onChanged: (v) => setState(() => _allergies = v),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Monitoring & compliance',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                _dropdown(
                  'Monitoring consent',
                  _monitoringConsent,
                  const [
                    'not_required',
                    'resident',
                    'representative',
                    'declined',
                  ],
                  (v) => setState(() => _monitoringConsent = v),
                  labelFor: Labels.monitoringConsent,
                ),
                const SizedBox(height: 12),
                if (_monitoringConsent == 'representative')
                  TextFormField(
                    controller: _consentRepresentative,
                    decoration: const InputDecoration(
                      labelText: 'Lawful representative',
                    ),
                  ),
                if (_monitoringConsent == 'representative')
                  const SizedBox(height: 12),
                TextFormField(
                  controller: _consentRecordedAt,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Consent recorded on',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await _pickDate(
                          initialDate: _consentRecordedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _consentRecordedDate = picked;
                            _consentRecordedAt.text = DateFormat(
                              'd MMM yyyy',
                            ).format(picked);
                          });
                        }
                      },
                    ),
                  ),
                  onTap: () async {
                    final picked = await _pickDate(
                      initialDate: _consentRecordedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _consentRecordedDate = picked;
                        _consentRecordedAt.text = DateFormat(
                          'd MMM yyyy',
                        ).format(picked);
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Monitoring methods',
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _monitoringOptions
                        .map(
                          (option) => FilterChip(
                            label: Text(Labels.monitoringMethod(option)),
                            selected: _monitoringMethods.contains(option),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _monitoringMethods = [
                                    ..._monitoringMethods,
                                    option,
                                  ];
                                } else {
                                  _monitoringMethods = _monitoringMethods
                                      .where((item) => item != option)
                                      .toList();
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gp,
                  decoration: const InputDecoration(labelText: 'GP name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nextOfKin,
                  decoration: const InputDecoration(labelText: 'Next of kin'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nextOfKinPhone,
                  decoration: const InputDecoration(
                    labelText: 'Next of kin phone',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _dropdown(
                  'Mobility',
                  _mobility,
                  const [
                    'independent',
                    'walking_aid',
                    'wheelchair',
                    'bedbound',
                  ],
                  (v) => setState(() => _mobility = v),
                  labelFor: Labels.mobility,
                ),
                const SizedBox(height: 12),
                _dropdown(
                  'Fall risk',
                  _fallRisk,
                  const ['low', 'medium', 'high'],
                  (v) => setState(() => _fallRisk = v),
                  labelFor: Labels.fallRisk,
                ),
                const SizedBox(height: 12),
                _dropdown(
                  'Nutrition risk (MUST)',
                  _nutritionRisk,
                  const ['low', 'medium', 'high'],
                  (v) => setState(() => _nutritionRisk = v),
                  labelFor: Labels.fallRisk,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _outcomeReview,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Next outcome review',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await _pickDate(
                          initialDate: _outcomeReviewDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                        );
                        if (picked != null) {
                          setState(() {
                            _outcomeReviewDate = picked;
                            _outcomeReview.text = DateFormat(
                              'd MMM yyyy',
                            ).format(picked);
                          });
                        }
                      },
                    ),
                  ),
                  onTap: () async {
                    final picked = await _pickDate(
                      initialDate: _outcomeReviewDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                    );
                    if (picked != null) {
                      setState(() {
                        _outcomeReviewDate = picked;
                        _outcomeReview.text = DateFormat(
                          'd MMM yyyy',
                        ).format(picked);
                      });
                    }
                  },
                ),
                SwitchListTile(
                  value: _dnacpr,
                  onChanged: (v) => setState(() => _dnacpr = v),
                  title: const Text('DNACPR in place'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save resident'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged, {
    String Function(String)? labelFor,
  }) {
    final safeValue = options.contains(value) ? value : options.first;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(labelText: label),
      items: options
          .map(
            (o) => DropdownMenuItem(
              value: o,
              child: Text(labelFor != null ? labelFor(o) : o),
            ),
          )
          .toList(),
      onChanged: (v) => onChanged(v!),
    );
  }

  Widget _profile(Resident r) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
              backgroundImage: r.photoUrl != null
                  ? NetworkImage(r.photoUrl!)
                  : null,
              child: r.photoUrl == null
                  ? Text(
                      r.firstName.isNotEmpty ? r.firstName[0] : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        color: AppTheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.fullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Room ${r.roomNumber ?? '—'} · Age ${r.age ?? '—'}'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      StatusPill(
                        label: Labels.careLevel(r.careLevel),
                        severity: 'info',
                      ),
                      StatusPill(
                        label: 'Fall: ${Labels.fallRisk(r.fallRisk)}',
                        severity: r.fallRisk,
                      ),
                      if (r.dnacpr)
                        const StatusPill(label: 'DNACPR', severity: 'high'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _TodayMedsCard(resident: r),
        const SizedBox(height: 4),
        if (r.careLevel == 'home_care' && r.address != null)
          _section('Home address', r.address!),
        _section('Conditions', r.conditions.join(', ').ifEmptyDash()),
        _section('Allergies', r.allergies.join(', ').ifEmptyDash()),
        _section(
          'Monitoring methods',
          r.monitoringMethods
              .map(Labels.monitoringMethod)
              .join(', ')
              .ifEmptyDash(),
        ),
        _section(
          'Monitoring consent',
          Labels.monitoringConsent(r.monitoringConsent),
        ),
        if (r.consentRepresentative != null)
          _section(
            'Lawful representative',
            r.consentRepresentative!.ifEmptyDash(),
          ),
        _section(
          'Consent recorded on',
          r.consentRecordedAt == null
              ? '—'
              : DateFormat('d MMM yyyy').format(r.consentRecordedAt!),
        ),
        _section('Mobility', Labels.mobility(r.mobility)),
        _section('Nutrition risk', Labels.fallRisk(r.nutritionRisk)),
        _section(
          'Next outcome review',
          r.outcomeReviewDate == null
              ? '—'
              : DateFormat('d MMM yyyy').format(r.outcomeReviewDate!),
        ),
        _section('GP', r.gpName?.ifEmptyDash() ?? '—'),
        _section(
          'Next of kin',
          [
            r.nextOfKin ?? '—',
            if (r.nextOfKinPhone != null) r.nextOfKinPhone!,
          ].join('\n'),
        ),
        const SizedBox(height: 20),
        ..._actionItems(r),
      ],
    );
  }

  Widget _section(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  List<Widget> _actionItems(Resident r) {
    final items = [
      if (r.careLevel == 'home_care')
        _ActionData('Today\'s visits', Icons.home_outlined, () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => HomeCareCallsScreen(resident: r)),
          );
        }),
      if (r.careLevel == 'home_care')
        _ActionData('Visit history', Icons.history_outlined, () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VisitHistoryScreen(resident: r),
            ),
          );
        }),
      _ActionData('Care plan', Icons.assignment_outlined, () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CarePlanScreen(resident: r)),
        );
      }),
      _ActionData('Risk assessments', Icons.health_and_safety_outlined, () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RiskAssessmentScreen(resident: r)),
        );
      }),
      _ActionData('DoLS', Icons.lock_outlined, () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DoLsScreen(resident: r)),
        );
      }),
      _ActionData('Lasting Powers (LPA)', Icons.gavel_outlined, () {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => LastingPowersScreen(resident: r)),
        );
      }),
      _ActionData('Advance Decisions', Icons.do_not_disturb_on_outlined, () {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => AdvanceDecisionsScreen(resident: r)),
        );
      }),
      _ActionData('Capacity (MCA)', Icons.psychology_outlined, () {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => CapacityAssessmentsScreen(resident: r)),
        );
      }),
      _ActionData('CHC Checklist', Icons.fact_check_outlined, () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChcScreen(resident: r)),
        );
      }),
      _ActionData('Safeguarding', Icons.shield_outlined, () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SafeguardingScreen(resident: r)),
        );
      }),
      _ActionData('NHS Continuing Healthcare (CHC)', Icons.health_and_safety_outlined, () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChcScreen(resident: r)),
        );
      }),
      _ActionData('Vitals / NEWS2', Icons.monitor_heart, () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => VitalsScreen(resident: r)));
      }),
      _ActionData('Medication (MAR)', Icons.medication, () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MedicationScreen(resident: r)),
        );
      }),
      _ActionData('Report incident', Icons.report_problem, () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => IncidentFormScreen(resident: r)),
        );
      }),
      _ActionData('Incidents history', Icons.history, () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => IncidentsScreen(residentId: r.id)),
        );
      }),
    ];
    return items
        .map(
          (a) => Card(
            child: ListTile(
              leading: Icon(a.icon, color: AppTheme.primary),
              title: Text(a.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: a.onTap,
            ),
          ),
        )
        .toList();
  }
}

class _ActionData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _ActionData(this.label, this.icon, this.onTap);
}

extension _DashExt on String {
  String ifEmptyDash() => trim().isEmpty ? '—' : this;
}

// ── Today's medications checklist card ───────────────────────────────────────

class _TodayMedsCard extends StatefulWidget {
  final Resident resident;
  const _TodayMedsCard({required this.resident});
  @override
  State<_TodayMedsCard> createState() => _TodayMedsCardState();
}

class _TodayMedsCardState extends State<_TodayMedsCard> {
  final _service = MedicationService();
  List<DueMedication> _slots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final all = await _service.dueMedications(
        from: DateTime(now.year, now.month, now.day),
        to: DateTime(now.year, now.month, now.day, 23, 59),
      );
      if (mounted) {
        setState(() {
          _slots = all
              .where((m) => m.residentId == widget.resident.id)
              .toList()
            ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final given = _slots.where((m) => m.given).length;
    final total = _slots.length;
    final hasOverdue = _slots.any((m) => m.isOverdue);
    final headerColor = total == 0
        ? Colors.black54
        : hasOverdue
            ? AppTheme.critical
            : given == total
                ? AppTheme.ok
                : AppTheme.warning;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MedicationScreen(resident: widget.resident, initialTab: 1),
          ),
        ).then((_) => _load()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.medication_outlined, size: 18, color: headerColor),
                  const SizedBox(width: 8),
                  Text(
                    "Today's medications",
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: headerColor),
                  ),
                  const Spacer(),
                  if (!_loading && total > 0)
                    Text('$given / $total',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: headerColor)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: Colors.black38, size: 20),
                ],
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_slots.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('No medications scheduled today',
                      style: TextStyle(color: Colors.black54, fontSize: 13)),
                )
              else ...[
                const SizedBox(height: 10),
                ..._slots.map(_slotRow),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotRow(DueMedication m) {
    final Color color;
    final IconData icon;
    if (m.given) {
      color = AppTheme.ok;
      icon = Icons.check_circle;
    } else if (m.isOverdue) {
      color = AppTheme.critical;
      icon = Icons.warning_amber_rounded;
    } else {
      color = Colors.black38;
      icon = Icons.radio_button_unchecked;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(m.timeLabel,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${m.name} ${m.dose}',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          if (m.controlledDrug)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('CD',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.critical)),
            ),
        ],
      ),
    );
  }
}

// ── Chip / tag input field ─────────────────────────────────────────────────────

class _TagsField extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final Color? chipColor;
  final TextEditingController inputController;

  const _TagsField({
    required this.label,
    required this.hint,
    required this.tags,
    required this.onChanged,
    required this.inputController,
    this.chipColor,
  });

  @override
  State<_TagsField> createState() => _TagsFieldState();
}

class _TagsFieldState extends State<_TagsField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final parts = raw.split(',');
    final updated = List<String>.from(widget.tags);
    for (final p in parts) {
      final t = p.trim();
      if (t.isNotEmpty && !updated.contains(t)) updated.add(t);
    }
    widget.onChanged(updated);
    widget.inputController.clear();
  }

  void _removeTag(String tag) {
    widget.onChanged(List<String>.from(widget.tags)..remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = widget.chipColor ?? AppTheme.primary;
    return InputDecorator(
      decoration: InputDecoration(labelText: widget.label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.tags
                  .map(
                    (t) => Chip(
                      label: Text(
                        t,
                        style: TextStyle(
                          color: chipColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: chipColor.withValues(alpha: 0.1),
                      side: BorderSide(color: chipColor.withValues(alpha: 0.3)),
                      deleteIconColor: chipColor,
                      onDeleted: () => _removeTag(t),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: widget.inputController,
            focusNode: _focus,
            decoration: InputDecoration(
              hintText: widget.hint,
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              suffixIcon: IconButton(
                icon: const Icon(Icons.add, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  if (widget.inputController.text.trim().isNotEmpty) {
                    _addTag(widget.inputController.text);
                  }
                },
              ),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) _addTag(v);
              _focus.requestFocus();
            },
            onChanged: (v) {
              if (v.endsWith(',')) _addTag(v.replaceAll(',', ''));
            },
          ),
        ],
      ),
    );
  }
}
