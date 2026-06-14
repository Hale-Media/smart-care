import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../models/cqc.dart';
import '../../services/cqc_service.dart';
import '../../providers/auth_provider.dart';
import '../../screens/settings/cqc_screen.dart';
import 'status_pill.dart';

/// Shows the active home's CQC rating on the dashboard. Reloads when the home
/// is switched. For admins with no link yet, offers a shortcut to set one.
class HomeCqcBadge extends StatefulWidget {
  const HomeCqcBadge({super.key});
  @override
  State<HomeCqcBadge> createState() => _HomeCqcBadgeState();
}

class _HomeCqcBadgeState extends State<HomeCqcBadge> {
  final _service = CqcService();
  HomeCqc? _data;
  bool _loading = true;
  int? _loadedFor;

  Future<void> _load({bool refresh = false}) async {
    setState(() => _loading = true);
    try {
      _data = await _service.homeRating(refresh: refresh);
    } catch (_) {
      _data = null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Reload when the active home changes (or first build).
    if (_loadedFor != auth.activeHomeId) {
      _loadedFor = auth.activeHomeId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

    if (_loading && _data == null) {
      return const SizedBox.shrink();
    }

    final isAdmin = auth.user?.role == StaffRole.admin;

    // Not linked yet.
    if (_data == null || !_data!.linked) {
      if (!isAdmin) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CqcScreen()),
          ),
          icon: const Icon(Icons.verified_outlined, size: 18),
          label: const Text('Link CQC rating'),
        ),
      );
    }

    final rating = _data!.rating;
    return Row(
      children: [
        const Text('CQC rating',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        if (rating == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('NOT RATED',
                style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          )
        else
          StatusPill(label: rating.toUpperCase(), severity: cqcSeverity(rating)),
        if (_data!.ratingDate != null) ...[
          const SizedBox(width: 8),
          Text(_data!.ratingDate!,
              style: const TextStyle(color: Colors.black45, fontSize: 12)),
        ],
        const Spacer(),
        IconButton(
          tooltip: 'Refresh from CQC',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh, size: 18, color: AppTheme.primary),
          onPressed: _loading ? null : () => _load(refresh: true),
        ),
      ],
    );
  }
}
