import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/home_care_call.dart';
import '../../models/resident.dart';
import '../../services/home_care_call_service.dart';
import '../../utils/labels.dart';

class VisitHistoryScreen extends StatefulWidget {
  /// If provided, the screen is pre-filtered to this resident.
  final Resident? resident;

  const VisitHistoryScreen({super.key, this.resident});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  final _service = HomeCareCallService();
  final _dateFmt = DateFormat('d MMM yyyy');

  DateTime _start = DateTime.now().subtract(const Duration(days: 6));
  DateTime _end = DateTime.now();
  String? _status; // null = all, 'confirmed', 'pending'

  List<HomeCareCall> _calls = [];
  bool _loading = false;
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
      final calls = await _service.history(
        startDate: _start,
        endDate: _end,
        residentId: widget.resident?.id,
        status: _status,
      );
      if (mounted) setState(() => _calls = calls);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppTheme.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _start = picked.start;
        _end = picked.end;
      });
      _load();
    }
  }

  int get _confirmed => _calls.where((c) => c.confirmed).length;
  int get _pending => _calls.where((c) => !c.confirmed).length;

  @override
  Widget build(BuildContext context) {
    final title = widget.resident != null
        ? '${widget.resident!.firstName}\'s Visit History'
        : 'Visit History';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Change date range',
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateRangeBar(
            start: _start,
            end: _end,
            fmt: _dateFmt,
            onTap: _pickDateRange,
          ),
          _FilterChips(
            current: _status,
            onChanged: (v) {
              setState(() => _status = v);
              _load();
            },
          ),
          if (!_loading && _error == null)
            _SummaryRow(
              total: _calls.length,
              confirmed: _confirmed,
              pending: _pending,
            ),
          const Divider(height: 1),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_calls.isEmpty) {
      return Center(
        child: Text(
          'No visits found for\n${_dateFmt.format(_start)} – ${_dateFmt.format(_end)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _calls.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _VisitCard(call: _calls[i]),
      ),
    );
  }
}

class _DateRangeBar extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final DateFormat fmt;
  final VoidCallback onTap;

  const _DateRangeBar({
    required this.start,
    required this.end,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
            const SizedBox(width: 8),
            Text(
              '${fmt.format(start)} – ${fmt.format(end)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String? current;
  final ValueChanged<String?> onChanged;

  const _FilterChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          _chip(context, label: 'All', value: null),
          const SizedBox(width: 8),
          _chip(context, label: 'Confirmed', value: 'confirmed'),
          const SizedBox(width: 8),
          _chip(context, label: 'Pending', value: 'pending'),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, {required String label, String? value}) {
    final selected = current == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(value),
      selectedColor: AppTheme.primary.withValues(alpha: 0.18),
      checkmarkColor: AppTheme.primary,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int total;
  final int confirmed;
  final int pending;

  const _SummaryRow({
    required this.total,
    required this.confirmed,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          _stat('Total', total, Colors.black87),
          const SizedBox(width: 16),
          _stat('Confirmed', confirmed, Colors.green),
          const SizedBox(width: 16),
          _stat('Pending', pending, Colors.orange),
        ],
      ),
    );
  }

  Widget _stat(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  final HomeCareCall call;

  const _VisitCard({required this.call});

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;

    if (call.confirmed) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${call.dateLabel}  •  ${call.scheduledTime}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    call.confirmed ? 'Confirmed' : 'Pending',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (call.residentName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                call.residentName,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
            if (call.confirmed && call.confirmedByName != null) ...[
              const SizedBox(height: 4),
              Text(
                'By ${call.confirmedByName}'
                '${call.confirmedAt != null ? '  •  ${DateFormat('HH:mm').format(call.confirmedAt!)}' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (call.careProvided != null &&
                call.careProvided!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Care: ${call.careProvided}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                _infoChip(
                  Labels.wellbeingStatus(call.wellbeingStatus),
                  call.wellbeingStatus == 'stable'
                      ? Colors.blueGrey
                      : Colors.deepOrange,
                ),
                if (call.safetyChecked) ...[
                  const SizedBox(width: 6),
                  _infoChip('Safety checked', Colors.blueGrey),
                ],
                if (call.reviewRequired) ...[
                  const SizedBox(width: 6),
                  _infoChip('Review needed', Colors.orange),
                ],
                if (call.escalatedTo != null &&
                    call.escalatedTo!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _infoChip('Escalated', Colors.redAccent),
                ],
              ],
            ),
            if (call.notes != null && call.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                call.notes!,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9)),
        ),
      );
}
