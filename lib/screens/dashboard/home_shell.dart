import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/alert_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incident_provider.dart';
import '../../providers/resident_provider.dart';
import '../ai/ai_screen.dart';
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
      const AiScreen(),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _index = 5),
        tooltip: 'AI',
        child: Icon(
          _index == 5 ? Icons.psychology : Icons.psychology_outlined,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            Expanded(child: _NavBtn(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dash', index: 0, current: _index, onTap: (i) => setState(() => _index = i))),
            Expanded(child: _NavBtn(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Residents', index: 1, current: _index, onTap: (i) => setState(() => _index = i))),
            Expanded(
              child: _NavBtn(
                icon: Icons.notifications_outlined,
                selectedIcon: Icons.notifications,
                label: 'Alerts',
                index: 2,
                current: _index,
                onTap: (i) => setState(() => _index = i),
                badge: openAlerts,
              ),
            ),
            const SizedBox(width: 56),
            Expanded(child: _NavBtn(icon: Icons.checklist_outlined, selectedIcon: Icons.checklist, label: 'Rounds', index: 3, current: _index, onTap: (i) => setState(() => _index = i))),
            Expanded(child: _NavBtn(icon: Icons.report_problem_outlined, selectedIcon: Icons.report_problem, label: 'Incidents', index: 4, current: _index, onTap: (i) => setState(() => _index = i))),
            Expanded(child: _NavBtn(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings', index: 6, current: _index, onTap: (i) => setState(() => _index = i))),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            child: Icon(selected ? selectedIcon : icon, color: color),
          ),
        ),
      ),
    );
  }
}
