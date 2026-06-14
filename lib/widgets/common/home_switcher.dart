// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/home.dart';
import '../../services/home_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resident_provider.dart';
import '../../providers/alert_provider.dart';

/// Compact control that shows the active home and, for companies with more than
/// one home, lets the user switch. Hidden entirely for single-home companies.
class HomeSwitcher extends StatefulWidget {
  const HomeSwitcher({super.key});
  @override
  State<HomeSwitcher> createState() => _HomeSwitcherState();
}

class _HomeSwitcherState extends State<HomeSwitcher> {
  final _service = HomeService();
  List<Home> _homes = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final homes = await _service.list();
      if (!mounted) return;
      setState(() {
        _homes = homes;
        _loaded = true;
      });
      // Resolve the active home name if we don't have it yet.
      final auth = context.read<AuthProvider>();
      if (auth.activeHomeName == null || auth.activeHomeName!.isEmpty) {
        final active = homes.where((h) => h.id == auth.activeHomeId);
        if (active.isNotEmpty) {
          // Reflect the name without a network round-trip.
          setState(() {});
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _activeName(AuthProvider auth) {
    if (auth.activeHomeName != null && auth.activeHomeName!.isNotEmpty) {
      return auth.activeHomeName!;
    }
    final match = _homes.where((h) => h.id == auth.activeHomeId);
    return match.isNotEmpty ? match.first.name : 'This home';
  }

  Future<void> _openPicker() async {
    final auth = context.read<AuthProvider>();
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Switch home',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            ..._homes.map(
              (h) => RadioListTile<int>(
                value: h.id,
                // ignore: deprecated_member_use
                groupValue: auth.activeHomeId,
                // ignore: deprecated_member_use
                onChanged: (v) => Navigator.pop(context, v),
                title: Text(h.name),
                subtitle: Text('${h.residentCount} residents'),
                activeColor: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null || selected == auth.activeHomeId) return;

    final ok = await auth.switchHome(selected);
    if (!mounted) return;
    if (ok) {
      // Refresh everything that's scoped to the active home.
      await context.read<ResidentProvider>().load();
      await context.read<AlertProvider>().load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to ${_activeName(auth)}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Could not switch home')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final maySwitch = auth.canSwitchHomes;
    // Nothing to switch between — don't clutter the UI.
    if (!_loaded || _homes.length <= 1) {
      if (_homes.length == 1) {
        return _chip(_activeName(auth), tappable: false);
      }
      return const SizedBox.shrink();
    }
    // Multiple homes exist, but only show the picker to permitted users.
    return _chip(_activeName(auth), tappable: maySwitch);
  }

  Widget _chip(String name, {required bool tappable}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.home_work_outlined,
            size: 18,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
          ),
          if (tappable) ...[
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 18, color: AppTheme.primary),
          ],
        ],
      ),
    );
    if (!tappable) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openPicker,
      child: child,
    );
  }
}
