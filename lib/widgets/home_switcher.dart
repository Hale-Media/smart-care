import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/home.dart';
import '../services/home_service.dart';
import '../providers/auth_provider.dart';
import '../providers/resident_provider.dart';
import '../providers/alert_provider.dart';

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
    final residents = context.read<ResidentProvider>();
    final alerts = context.read<AlertProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
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
            RadioGroup<int>(
              groupValue: auth.activeHomeId,
              onChanged: (v) => Navigator.pop(sheetCtx, v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _homes
                    .map(
                      (h) => RadioListTile<int>(
                        value: h.id,
                        title: Text(h.name),
                        subtitle: Text('${h.residentCount} residents'),
                        activeColor: AppTheme.primary,
                      ),
                    )
                    .toList(),
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
      await residents.load(homeId: auth.activeHomeId);
      await alerts.load();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Switched to ${_activeName(auth)}')),
        );
      }
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Could not switch home')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final maySwitch = auth.canSwitchHomes;
    if (!_loaded || _homes.length <= 1) {
      if (_homes.length == 1) {
        return _chip(_activeName(auth), tappable: false);
      }
      return const SizedBox.shrink();
    }
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
