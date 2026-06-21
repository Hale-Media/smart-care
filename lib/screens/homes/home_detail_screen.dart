// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/home.dart';
import '../../models/resident.dart';
import '../../models/staff_user.dart';
import '../../services/home_service.dart';
import '../../services/resident_service.dart';
import '../../services/staff_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_pill.dart';
import '../residents/resident_detail_screen.dart';

class HomeDetailScreen extends StatefulWidget {
  final Home home;
  const HomeDetailScreen({super.key, required this.home});

  @override
  State<HomeDetailScreen> createState() => _HomeDetailScreenState();
}

class _HomeDetailScreenState extends State<HomeDetailScreen>
    with SingleTickerProviderStateMixin {
  final _staffService = StaffService();
  final _homeService = HomeService();
  final _residentService = ResidentService();

  late final TabController _tabs = TabController(length: 2, vsync: this);

  List<StaffUser> _staff = [];
  List<Resident> _residents = [];
  bool _loadingStaff = true;
  bool _loadingResidents = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
    _loadResidents();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() => _loadingStaff = true);
    try {
      final all = await _staffService.list();
      _staff = all.where((s) => s.homeId == widget.home.id).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _loadingStaff = false);
  }

  Future<void> _loadResidents() async {
    setState(() => _loadingResidents = true);
    try {
      _residents = await _residentService.list(homeId: widget.home.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _loadingResidents = false);
  }

  // ── Staff FAB — sheet to pick create vs assign ────────────────────────────

  void _onStaffFab() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('Create new staff account'),
              subtitle: const Text(
                'Set up login credentials for a new team member',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateStaffDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.transfer_within_a_station_outlined),
              title: const Text('Assign existing staff'),
              subtitle: const Text(
                'Move a staff member from another home here',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showAssignExistingDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Create new staff ──────────────────────────────────────────────────────

  Future<void> _showCreateStaffDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    StaffRole selectedRole = StaffRole.carer;
    bool saving = false;
    bool showPass = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text('Add staff — ${widget.home.name}'),
          scrollable: true,
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setInner(() => showPass = !showPass),
                    ),
                  ),
                  obscureText: !showPass,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 8) return 'At least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<StaffRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role *',
                    border: OutlineInputBorder(),
                  ),
                  items: StaffRole.values
                      .map(
                        (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                      )
                      .toList(),
                  onChanged: (v) => setInner(() => selectedRole = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'PIN (optional, 4–6 digits)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (!RegExp(r'^\d{4,6}$').hasMatch(v)) {
                      return '4–6 digits only';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setInner(() => saving = true);
                      try {
                        await _staffService.create(
                          name: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          password: passCtrl.text,
                          role: selectedRole,
                          homeId: widget.home.id,
                          pin: pinCtrl.text.isNotEmpty ? pinCtrl.text : null,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadStaff();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      } finally {
                        if (ctx.mounted) setInner(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Assign existing staff ─────────────────────────────────────────────────

  Future<void> _showAssignExistingDialog() async {
    final List<StaffUser> available;
    try {
      final all = await _staffService.list();
      final filtered = all
          .where((s) => s.homeId != widget.home.id && s.active)
          .toList()
        ..sort((a, b) {
          final homeCmp = (a.homeName ?? '').compareTo(b.homeName ?? '');
          return homeCmp != 0 ? homeCmp : a.name.compareTo(b.name);
        });
      available = filtered;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }

    if (!mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All active staff are already at this home.')),
      );
      return;
    }

    final selected = <int>{};
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          final items = available;
          return AlertDialog(
            title: Text('Assign to ${widget.home.name}'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final s = items[i];
                  return CheckboxListTile(
                    value: selected.contains(s.id),
                    onChanged: saving
                        ? null
                        : (v) => setInner(() {
                            if (v == true) {
                              selected.add(s.id);
                            } else {
                              selected.remove(s.id);
                            }
                          }),
                    title: Text(s.name),
                    subtitle: Text(
                      '${s.role.label}${s.homeName != null ? ' · ${s.homeName}' : ''}',
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: (saving || selected.isEmpty)
                    ? null
                    : () async {
                        setInner(() => saving = true);
                        try {
                          for (final staffId in selected) {
                            await _staffService.reassignHome(
                              staffId,
                              widget.home.id,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadStaff();
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(
                              ctx,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                          }
                          if (ctx.mounted) setInner(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Assign (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Move a staff member to another home ───────────────────────────────────

  Future<void> _moveStaffToHome(StaffUser staff) async {
    final List<Home> homes;
    try {
      final all = await _homeService.list();
      homes = all.where((h) => h.id != widget.home.id).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }

    if (!mounted) return;

    if (homes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other homes available.')),
      );
      return;
    }

    final picked = await showDialog<Home>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Move ${staff.name} to…'),
        children: homes
            .map(
              (h) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, h),
                child: Text(h.name),
              ),
            )
            .toList(),
      ),
    );

    if (picked == null || !mounted) return;

    try {
      await _staffService.reassignHome(staff.id, picked.id);
      await _loadStaff();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${staff.name} moved to ${picked.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _addResident() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ResidentDetailScreen(forHomeId: widget.home.id),
      ),
    );
    if (added == true) _loadResidents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.home.name),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Staff'),
            Tab(icon: Icon(Icons.elderly_outlined), text: 'Residents'),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
      body: TabBarView(
        controller: _tabs,
        children: [_staffTab(), _residentsTab()],
      ),
    );
  }

  Widget _buildFab() {
    return ListenableBuilder(
      listenable: _tabs,
      builder: (_, _) => _tabs.index == 0
          ? FloatingActionButton.extended(
              heroTag: 'fab_staff',
              onPressed: _onStaffFab,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add staff'),
            )
          : FloatingActionButton.extended(
              heroTag: 'fab_resident',
              onPressed: _addResident,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add resident'),
            ),
    );
  }

  // ── Staff tab ────────────────────────────────────────────────────────────

  Widget _staffTab() {
    if (_loadingStaff) return const LoadingView();
    if (_staff.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'No staff at this home',
        subtitle: 'Tap "Add staff" to create or assign a team member.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadStaff,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
        itemCount: _staff.length,
        itemBuilder: (_, i) => _StaffTile(
          staff: _staff[i],
          onMove: () => _moveStaffToHome(_staff[i]),
        ),
      ),
    );
  }

  // ── Residents tab ────────────────────────────────────────────────────────

  Widget _residentsTab() {
    if (_loadingResidents) return const LoadingView();
    if (_residents.isEmpty) {
      return const EmptyState(
        icon: Icons.elderly_outlined,
        title: 'No residents at this home',
        subtitle: 'Tap "Add resident" to admit the first resident.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadResidents,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
        itemCount: _residents.length,
        itemBuilder: (_, i) => _ResidentTile(resident: _residents[i]),
      ),
    );
  }
}

// ── Staff tile ───────────────────────────────────────────────────────────────

class _StaffTile extends StatelessWidget {
  final StaffUser staff;
  final VoidCallback onMove;
  const _StaffTile({required this.staff, required this.onMove});

  Color get _roleColor {
    switch (staff.role) {
      case StaffRole.admin:
        return Colors.purple;
      case StaffRole.manager:
        return AppTheme.primary;
      case StaffRole.nurse:
        return Colors.blue;
      case StaffRole.seniorCarer:
        return Colors.teal;
      case StaffRole.carer:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: staff.active
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
          child: Text(
            staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: staff.active ? AppTheme.primary : Colors.grey,
            ),
          ),
        ),
        title: Text(
          staff.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _roleColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    staff.role.label,
                    style: TextStyle(
                      color: _roleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!staff.active)
                  const Text(
                    '· Inactive',
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              staff.email,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (v) {
            if (v == 'move') onMove();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'move',
              child: Row(
                children: [
                  Icon(Icons.transfer_within_a_station_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Move to another home'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Resident tile ────────────────────────────────────────────────────────────

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
                  style: const TextStyle(color: AppTheme.primary),
                )
              : null,
        ),
        title: Text(
          resident.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Room ${resident.roomNumber ?? '—'} · ${resident.careLevel} · Age ${resident.age ?? '—'}',
        ),
        trailing: resident.fallRisk == 'high'
            ? const StatusPill(label: 'FALL RISK', severity: 'high')
            : const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResidentDetailScreen(resident: resident),
          ),
        ),
      ),
    );
  }
}
