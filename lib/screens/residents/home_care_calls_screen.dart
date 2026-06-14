import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/home_care_call.dart';
import '../../models/resident.dart';
import '../../services/home_care_call_service.dart';
import '../../utils/labels.dart';

class HomeCareCallsScreen extends StatefulWidget {
  final Resident resident;
  const HomeCareCallsScreen({super.key, required this.resident});

  @override
  State<HomeCareCallsScreen> createState() => _HomeCareCallsScreenState();
}

class _HomeCareCallsScreenState extends State<HomeCareCallsScreen> {
  final _service = HomeCareCallService();
  List<HomeCareCall> _calls = [];
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
      final calls = await _service.generateToday(widget.resident.id);
      if (mounted) setState(() => _calls = calls..sort(_sortCalls));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _sortCalls(HomeCareCall a, HomeCareCall b) =>
      a.scheduledTime.compareTo(b.scheduledTime);

  Future<void> _confirm(HomeCareCall call) async {
    final payload = await _showConfirmDialog(call);
    if (payload == null) return;
    try {
      final updated = await _service.confirm(
        call.id,
        notes: payload.notes,
        careProvided: payload.careProvided,
        safetyChecked: payload.safetyChecked,
        wellbeingStatus: payload.wellbeingStatus,
        escalatedTo: payload.escalatedTo,
        promotesIndependence: payload.promotesIndependence,
        reviewRequired: payload.reviewRequired,
      );
      setState(() {
        final idx = _calls.indexWhere((c) => c.id == call.id);
        if (idx != -1) _calls[idx] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<_VisitConfirmation?> _showConfirmDialog(HomeCareCall call) async {
    final notesCtrl = TextEditingController();
    final careCtrl = TextEditingController();
    final escalateCtrl = TextEditingController();
    var safetyChecked = true;
    var promotesIndependence = true;
    var reviewRequired = false;
    var wellbeingStatus = 'stable';
    return showDialog<_VisitConfirmation>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text('Confirm ${call.scheduledTime} visit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: careCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Care provided',
                    hintText:
                        'e.g. personal care, meal prep, medication prompt',
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: wellbeingStatus,
                  decoration: const InputDecoration(
                    labelText: 'Wellbeing observed',
                  ),
                  items:
                      const [
                            'stable',
                            'physical_change',
                            'mental_change',
                            'both',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(Labels.wellbeingStatus(value)),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setInner(() => wellbeingStatus = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: escalateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Escalated to',
                    hintText: 'e.g. care manager, GP, district nurse',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Daily record note',
                    hintText: 'e.g. service user was in good spirits',
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: safetyChecked,
                  onChanged: (value) => setInner(() => safetyChecked = value),
                  title: const Text('Home safety check completed'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: promotesIndependence,
                  onChanged: (value) =>
                      setInner(() => promotesIndependence = value),
                  title: const Text(
                    'Supported independence / strengths-based care',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: reviewRequired,
                  onChanged: (value) => setInner(() => reviewRequired = value),
                  title: const Text('Care package review needed'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(
                _VisitConfirmation(
                  notes: notesCtrl.text.trim(),
                  careProvided: careCtrl.text.trim(),
                  safetyChecked: safetyChecked,
                  wellbeingStatus: wellbeingStatus,
                  escalatedTo: escalateCtrl.text.trim(),
                  promotesIndependence: promotesIndependence,
                  reviewRequired: reviewRequired,
                ),
              ),
              child: const Text('Confirm visit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _complianceChips(HomeCareCall call) {
    final chips = <Widget>[];
    if (call.safetyChecked) {
      chips.add(_chip('Safety checked', Colors.blueGrey));
    }
    if (call.promotesIndependence) {
      chips.add(_chip('Independence supported', AppTheme.primary));
    }
    if (call.reviewRequired) {
      chips.add(_chip('Review needed', Colors.orange));
    }
    if (call.escalatedTo != null && call.escalatedTo!.isNotEmpty) {
      chips.add(_chip('Escalated', Colors.redAccent));
    }
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE d MMMM').format(DateTime.now());
    final r = widget.resident;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.fullName),
            Text(
              today,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: _calls.isEmpty
                  ? _EmptyView(resident: r)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _summaryHeader(),
                        const SizedBox(height: 12),
                        ..._calls.map(_callTile),
                      ],
                    ),
            ),
    );
  }

  Widget _summaryHeader() {
    final confirmed = _calls.where((c) => c.confirmed).length;
    final total = _calls.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$confirmed / $total visits confirmed today',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: total == 0 ? 0 : confirmed / total,
              backgroundColor: Colors.grey.shade200,
              color: confirmed == total ? Colors.green : AppTheme.primary,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callTile(HomeCareCall call) {
    final now = DateTime.now();
    final isDue = !call.confirmed && call.scheduledDateTime.isBefore(now);

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (call.confirmed) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusLabel = 'Confirmed';
    } else if (isDue) {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
      statusLabel = 'Due';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.radio_button_unchecked;
      statusLabel = 'Scheduled';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(statusIcon, color: statusColor, size: 22),
        ),
        title: Text(
          call.scheduledTime,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
            if (call.confirmed && call.confirmedAt != null) ...[
              Text(
                'By ${call.confirmedByName ?? 'staff'} at '
                '${DateFormat('HH:mm').format(call.confirmedAt!)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (call.notes != null && call.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  call.notes!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (call.careProvided != null && call.careProvided!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Care: ${call.careProvided!}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Wellbeing: ${Labels.wellbeingStatus(call.wellbeingStatus)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            if (call.escalatedTo != null && call.escalatedTo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Escalated to ${call.escalatedTo}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            _complianceChips(call),
          ],
        ),
        isThreeLine: call.confirmed,
        trailing: call.confirmed
            ? null
            : FilledButton(
                onPressed: () => _confirm(call),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Confirm'),
              ),
      ),
    );
  }
}

class _VisitConfirmation {
  final String notes;
  final String careProvided;
  final bool safetyChecked;
  final String wellbeingStatus;
  final String escalatedTo;
  final bool promotesIndependence;
  final bool reviewRequired;

  const _VisitConfirmation({
    required this.notes,
    required this.careProvided,
    required this.safetyChecked,
    required this.wellbeingStatus,
    required this.escalatedTo,
    required this.promotesIndependence,
    required this.reviewRequired,
  });
}

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
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  final Resident resident;
  const _EmptyView({required this.resident});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.home_outlined, size: 48, color: Colors.black26),
          const SizedBox(height: 16),
          const Text(
            'No visits scheduled for today.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            'Add visit times to ${resident.firstName}\'s profile to generate a daily schedule.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black38),
          ),
        ],
      ),
    ),
  );
}
