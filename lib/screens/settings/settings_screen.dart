import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../homes/homes_management_screen.dart';
import '../staff/staff_management_screen.dart';
import '../compliance/compliance_dashboard_screen.dart';
import 'cqc_screen.dart';
import 'gdpr_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (user != null)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user.name),
                subtitle: Text('${user.role.label} · ${user.email}'),
              ),
            ),
          const ListTile(
            leading: Icon(Icons.notifications_active_outlined),
            title: Text('Alert notifications'),
            subtitle: Text('Critical alerts use full-screen intent'),
          ),
          if (user != null && user.role.canManage)
            ListTile(
              leading: const Icon(Icons.security_outlined),
              title: const Text('Data protection'),
              subtitle: const Text('Subject access, restriction and erasure logs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GdprScreen()),
              ),
            )
          else
            const ListTile(
              leading: Icon(Icons.security_outlined),
              title: Text('Data protection'),
              subtitle: Text('UK GDPR compliant and audit logged'),
            ),          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: AppConfig.appName,
            applicationVersion: AppConfig.appVersion,
            child: Text('About'),
          ),
          if (user != null && user.role.canManage) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Manage homes'),
              subtitle: const Text('Add and view your care homes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HomesManagementScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Staff & permissions'),
              subtitle: const Text(
                'Add staff, set roles and home-switch access',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StaffManagementScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('Compliance dashboard'),
              subtitle: const Text(
                'Consent, reviews, risk, visits & staff competency',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ComplianceDashboardScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('CQC registration'),
              subtitle: const Text(
                'Link your CQC provider ID and view ratings',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CqcScreen())),
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign out', style: TextStyle(color: Colors.red)),
            onTap: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
    );
  }
}

