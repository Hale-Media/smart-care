import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/due_medication.dart';
import '../../models/resident.dart';
import '../../providers/resident_provider.dart';
import '../../services/medication_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import 'medication_screen.dart';

class OverdueMedsScreen extends StatefulWidget {
  const OverdueMedsScreen({super.key});

  @override
  State<OverdueMedsScreen> createState() => _OverdueMedsScreenState();
}

class _OverdueMedsScreenState extends State<OverdueMedsScreen> {
  final _service = MedicationService();
  List<DueMedication> _overdue = [];
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
      final now = DateTime.now();
      final meds = await _service.dueMedications(
        from: DateTime(now.year, now.month, now.day),
        to: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
      if (mounted) {
        setState(() {
          _overdue = meds.where((m) => m.isOverdue).toList()
            ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Group overdue meds by resident, preserving time-sorted order within each group.
  Map<int, List<DueMedication>> _byResident() {
    final map = <int, List<DueMedication>>{};
    for (final m in _overdue) {
      map.putIfAbsent(m.residentId, () => []).add(m);
    }
    return map;
  }

  Future<void> _openResident(Resident resident) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MedicationScreen(resident: resident, initialTab: 1),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overdue medications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_overdue.isEmpty) {
      return const EmptyState(
        icon: Icons.medication_outlined,
        title: 'No overdue medications',
        subtitle: 'All medications are up to date.',
      );
    }

    final grouped = _byResident();
    final groupedEntries = grouped.entries.toList();
    final residents = context.watch<ResidentProvider>();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: groupedEntries.length,
        itemBuilder: (context, i) {
          final residentId = groupedEntries[i].key;
          final meds = groupedEntries[i].value;
          final resident = residents.byId(residentId);
          return _ResidentMedsCard(
            residentId: residentId,
            residentName: meds.first.residentName,
            meds: meds,
            onTap: resident != null ? () => _openResident(resident) : null,
          );
        },
      ),
    );
  }
}

class _ResidentMedsCard extends StatelessWidget {
  final int residentId;
  final String residentName;
  final List<DueMedication> meds;
  final VoidCallback? onTap;

  const _ResidentMedsCard({
    required this.residentId,
    required this.residentName,
    required this.meds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.person, size: 18, color: AppTheme.critical),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      residentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '${meds.length} overdue',
                    style: const TextStyle(
                      color: AppTheme.critical,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.chevron_right, color: AppTheme.critical, size: 18),
                ],
              ),
              const Divider(height: 16),
              ...meds.map((m) => _MedRow(med: m)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedRow extends StatelessWidget {
  final DueMedication med;
  const _MedRow({required this.med});

  @override
  Widget build(BuildContext context) {
    final overdueBy = DateTime.now().difference(med.scheduledFor);
    final overdueLabel = overdueBy.inHours >= 1
        ? '${overdueBy.inHours}h overdue'
        : '${overdueBy.inMinutes}m overdue';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            DateFormat('HH:mm').format(med.scheduledFor),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.critical,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${med.name} ${med.dose}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          if (med.controlledDrug)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'CD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7B1FA2),
                ),
              ),
            ),
          Text(
            overdueLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.critical,
            ),
          ),
        ],
      ),
    );
  }
}
