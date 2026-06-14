import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/alert_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incident_provider.dart';
import '../../providers/resident_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../residents/residents_screen.dart';
import '../alerts/alerts_screen.dart';
import '../rounds/rounds_screen.dart';
import '../incidents/incidents_screen.dart';
import '../settings/settings_screen.dart';

/// Bottom-navigation shell hosting the main sections.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int? _loadedHomeId;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(onNavigate: (i) => setState(() => _index = i)),
      const ResidentsScreen(),
      const AlertsScreen(),
      const RoundsScreen(),
      const IncidentsScreen(),
      const SettingsScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final residents = context.read<ResidentProvider>();
      final alerts = context.read<AlertProvider>();
      final incidents = context.read<IncidentProvider>();
      _loadedHomeId = auth.activeHomeId;
      residents.load(homeId: _loadedHomeId);
      alerts.load();
      alerts.startPolling();
      incidents.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeHomeId = context.select<AuthProvider, int?>((a) => a.activeHomeId);
    final openAlerts = context.watch<AlertProvider>().openCount;

    if (_loadedHomeId != null && activeHomeId != _loadedHomeId) {
      _loadedHomeId = activeHomeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ResidentProvider>().load(homeId: activeHomeId);
        context.read<AlertProvider>().load();
        context.read<IncidentProvider>().load();
      });
    }
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dash',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Residents',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: openAlerts > 0,
              label: Text('$openAlerts'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Rounds',
          ),
          const NavigationDestination(
            icon: Icon(Icons.report_problem_outlined),
            selectedIcon: Icon(Icons.report_problem),
            label: 'Incidents',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
