import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/resident.dart';
import '../../providers/resident_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import '../../utils/labels.dart';
import '../../widgets/common/status_pill.dart';
import 'resident_detail_screen.dart';

class ResidentsScreen extends StatefulWidget {
  const ResidentsScreen({super.key});
  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends State<ResidentsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResidentProvider>();
    final residents = provider.residents
        .where((r) =>
            r.fullName.toLowerCase().contains(_query.toLowerCase()) ||
            (r.roomNumber ?? '').toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Residents')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or room',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: provider.loading
                ? const LoadingView()
                : residents.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'No residents',
                        subtitle: 'Add a resident to begin monitoring.')
                    : RefreshIndicator(
                        onRefresh: provider.load,
                        child: ListView.builder(
                          itemCount: residents.length,
                          itemBuilder: (_, i) =>
                              _ResidentTile(resident: residents[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_residents',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ResidentDetailScreen(),
        )),
        icon: const Icon(Icons.add),
        label: const Text('Add resident'),
      ),
    );
  }
}

class _ResidentTile extends StatelessWidget {
  final Resident resident;
  const _ResidentTile({required this.resident});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
          backgroundImage: resident.photoUrl != null
              ? NetworkImage(resident.photoUrl!)
              : null,
          child: resident.photoUrl == null
              ? Text(
                  resident.firstName.isNotEmpty ? resident.firstName[0] : '?',
                  style: const TextStyle(color: AppTheme.primary))
              : null,
        ),
        title: Text(resident.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            'Room ${resident.roomNumber ?? '—'} · ${Labels.careLevel(resident.careLevel)} · Age ${resident.age ?? '—'}'),
        trailing: resident.fallRisk == 'high'
            ? const StatusPill(label: 'FALL RISK', severity: 'high')
            : const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ResidentDetailScreen(resident: resident),
        )),
      ),
    );
  }
}
