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

class _ResidentsScreenState extends State<ResidentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _onHomeCareTab => _tabs.index == 1;

  List<Resident> _filter(List<Resident> all, bool homeCare) {
    final q = _query.toLowerCase();
    return all.where((r) {
      final matchesTab =
          homeCare ? r.careLevel == 'home_care' : r.careLevel != 'home_care';
      final matchesQuery = r.fullName.toLowerCase().contains(q) ||
          (homeCare
              ? (r.address ?? '').toLowerCase().contains(q)
              : (r.roomNumber ?? '').toLowerCase().contains(q));
      return matchesTab && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResidentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Residents'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Residential'),
            Tab(text: 'Home Care'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: _onHomeCareTab
                    ? 'Search by name or address'
                    : 'Search by name or room',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: provider.loading
                ? const LoadingView()
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _ResidentList(
                        residents: _filter(provider.residents, false),
                        onRefresh: provider.load,
                        emptyTitle: 'No residential residents',
                        emptySubtitle:
                            'Add a resident to begin monitoring.',
                      ),
                      _ResidentList(
                        residents: _filter(provider.residents, true),
                        onRefresh: provider.load,
                        emptyTitle: 'No home care service users',
                        emptySubtitle:
                            'Add a home care service user to begin monitoring.',
                        homeCare: true,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_residents',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ResidentDetailScreen(
            initialCareLevel:
                _onHomeCareTab ? 'home_care' : 'residential',
          ),
        )),
        icon: const Icon(Icons.add),
        label:
            Text(_onHomeCareTab ? 'Add service user' : 'Add resident'),
      ),
    );
  }
}

class _ResidentList extends StatelessWidget {
  final List<Resident> residents;
  final Future<void> Function() onRefresh;
  final String emptyTitle;
  final String emptySubtitle;
  final bool homeCare;

  const _ResidentList({
    required this.residents,
    required this.onRefresh,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.homeCare = false,
  });

  @override
  Widget build(BuildContext context) {
    if (residents.isEmpty) {
      return EmptyState(
        icon: homeCare ? Icons.home_outlined : Icons.people_outline,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        itemCount: residents.length,
        itemBuilder: (_, i) =>
            _ResidentTile(resident: residents[i], homeCare: homeCare),
      ),
    );
  }
}

class _ResidentTile extends StatelessWidget {
  final Resident resident;
  final bool homeCare;
  const _ResidentTile({required this.resident, this.homeCare = false});

  @override
  Widget build(BuildContext context) {
    final subtitle = homeCare
        ? '${resident.address ?? 'No address'} · Age ${resident.age ?? '—'}'
        : 'Room ${resident.roomNumber ?? '—'} · ${Labels.careLevel(resident.careLevel)} · Age ${resident.age ?? '—'}';

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
        subtitle: Text(subtitle),
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
