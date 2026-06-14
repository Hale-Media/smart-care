import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/home_care_call.dart';
import '../../models/resident.dart';
import '../../services/home_care_call_service.dart';

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
    final notes = await _showConfirmDialog(call);
    if (notes == null) return; // cancelled
    try {
      final updated = await _service.confirm(call.id, notes: notes);
      setState(() {
        final idx = _calls.indexWhere((c) => c.id == call.id);
        if (idx != -1) _calls[idx] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<String?> _showConfirmDialog(HomeCareCall call) async {
    final notesCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm ${call.scheduledTime} visit'),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'e.g. service user was in good spirits',
          ),
          maxLines: 3,
          minLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(notesCtrl.text.trim()),
            child: const Text('Confirm visit'),
          ),
        ],
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
            Text(today,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
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
            Text('$confirmed / $total visits confirmed today',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
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
        title: Text(call.scheduledTime,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(statusLabel,
                style: TextStyle(color: statusColor, fontSize: 12)),
            if (call.confirmed && call.confirmedAt != null) ...[
              Text(
                'By ${call.confirmedByName ?? 'staff'} at '
                '${DateFormat('HH:mm').format(call.confirmedAt!)}',
                style:
                    const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (call.notes != null && call.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(call.notes!,
                    style: const TextStyle(
                        fontSize: 12, fontStyle: FontStyle.italic)),
              ),
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
              const Text('No visits scheduled for today.',
                  style: TextStyle(color: Colors.black54)),
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
