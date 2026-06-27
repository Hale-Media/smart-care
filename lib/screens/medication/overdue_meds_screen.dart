import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/due_medication.dart';
import '../../providers/resident_provider.dart';
import 'medication_screen.dart';

/// Shows only the residents who have at least one overdue medication slot.
class OverdueMedsScreen extends StatelessWidget {
  final List<DueMedication> overdue;
  const OverdueMedsScreen({super.key, required this.overdue});

  @override
  Widget build(BuildContext context) {
    // Group overdue slots by residentId, preserving insertion order.
    final byResident = <int, List<DueMedication>>{};
    for (final m in overdue) {
      (byResident[m.residentId] ??= []).add(m);
    }
    final residentIds = byResident.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Overdue medications')),
      body: residentIds.isEmpty
          ? const Center(child: Text('No overdue medications'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: residentIds.length,
              itemBuilder: (context, i) {
                final id = residentIds[i];
                final slots = byResident[id]!;
                final name = slots.first.residentName;
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFEBEE),
                      child: Icon(Icons.medication, color: AppTheme.critical),
                    ),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      slots.map((s) => '${s.name} ${s.dose} · ${s.timeLabel}').join('\n'),
                    ),
                    isThreeLine: slots.length > 1,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final resident =
                          context.read<ResidentProvider>().byId(id);
                      if (resident == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MedicationScreen(resident: resident, initialTab: 1),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
