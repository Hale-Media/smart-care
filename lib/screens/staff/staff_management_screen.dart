// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/home.dart';
import '../../models/staff_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/home_service.dart';
import '../../services/staff_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import 'staff_competency_overview_screen.dart';
import 'staff_competency_screen.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});
  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _staffService = StaffService();
  final _homeService = HomeService();
  List<StaffUser> _staff = [];
  List<Home> _homes = [];
  bool _loading = true;
  final Set<int> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _staffService.list(),
        _homeService.list(),
      ]);
      _staff = results[0] as List<StaffUser>;
      _homes = results[1] as List<Home>;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleSwitch(StaffUser s, bool value) async {
    setState(() => _saving.add(s.id));
    try {
      await _staffService.setCanSwitchHomes(s.id, value);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(s.id));
    }
  }

  Future<void> _toggleActive(StaffUser s, bool value) async {
    setState(() => _saving.add(s.id));
    try {
      await _staffService.setActive(s.id, value);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(s.id));
    }
  }

  Future<void> _changeRole(StaffUser s) async {
    StaffRole? picked = s.role;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change role ÔÇö ${s.name}'),
        content: StatefulBuilder(
          builder: (ctx, setInner) => Column(
            mainAxisSize: MainAxisSize.min,
            children: StaffRole.values
                .map(
                  (r) => RadioListTile<StaffRole>(
                    title: Text(r.label),
                    value: r,
                    groupValue: picked,
                    onChanged: (v) => setInner(() => picked = v),
                    activeColor: AppTheme.primary,
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || picked == s.role) return;
    setState(() => _saving.add(s.id));
    try {
      await _staffService.updateRole(s.id, picked!);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(s.id));
    }
  }

  Future<void> _deleteStaff(StaffUser s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete staff member?'),
        content: Text(
          'This will permanently delete ${s.name}. '
          'If they have existing records, deactivate them instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving.add(s.id));
    try {
      await _staffService.delete(s.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(s.id));
    }
  }

  Future<void> _showAddStaffDialog() async {
    if (_homes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a home before adding staff.')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    StaffRole selectedRole = StaffRole.carer;
    int selectedHomeId = _homes.first.id;
    bool saving = false;
    bool showPass = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Add staff member'),
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
                if (_homes.length > 1) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedHomeId,
                    decoration: const InputDecoration(
                      labelText: 'Home *',
                      border: OutlineInputBorder(),
                    ),
                    items: _homes
                        .map(
                          (h) => DropdownMenuItem(
                            value: h.id,
                            child: Text(h.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setInner(() => selectedHomeId = v!),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: pinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'PIN (optional, 4ÔÇô6 digits)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (!RegExp(r'^\d{4,6}$').hasMatch(v)) {
                      return '4ÔÇô6 digits only';
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
                          homeId: selectedHomeId,
                          pin: pinCtrl.text.isNotEmpty ? pinCtrl.text : null,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff & permissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.school_outlined),
            tooltip: 'Competency overview',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StaffCompetencyOverviewScreen(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_staff_mgmt',
        onPressed: _showAddStaffDialog,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add staff'),
      ),
      body: _loading
          ? const LoadingView()
          : _staff.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline,
              title: 'No staff yet',
              subtitle: 'Tap "Add staff" to create the first account.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                children: _staff.map(_tile).toList(),
              ),
            ),
    );
  }

  Widget _tile(StaffUser s) {
    final isAdmin = s.role == StaffRole.admin;
    final busy = _saving.contains(s.id);
    final currentUserId = context.read<AuthProvider>().user?.id;
    final canDelete = !isAdmin && !busy && s.id != currentUserId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: CircleAvatar(
                backgroundColor: s.active
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.15),
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: s.active ? AppTheme.primary : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: s.active ? null : Colors.grey,
                          ),
                        ),
                      ),
                      if (!s.active)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.homeName != null ? '${s.homeName}' : '',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  // Role chip + change button
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _RoleChip(role: s.role),
                      if (!isAdmin && !busy)
                        InkWell(
                          onTap: () => _changeRole(s),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      if (!busy)
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StaffCompetencyScreen(staff: s),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              'Compliance',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Home-switch & active toggles
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 4,
                      children: [
                        _LabelledSwitch(
                          label: 'Switch homes',
                          value: s.maySwitchHomes,
                          disabled: isAdmin,
                          onChanged: isAdmin
                              ? null
                              : (v) => _toggleSwitch(s, v),
                        ),
                        _LabelledSwitch(
                          label: 'Active',
                          value: s.active,
                          disabled: isAdmin,
                          onChanged: isAdmin
                              ? null
                              : (v) => _toggleActive(s, v),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete staff member',
                onPressed: () => _deleteStaff(s),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final StaffRole role;
  const _RoleChip({required this.role});

  Color get _color {
    switch (role) {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LabelledSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final bool disabled;
  final ValueChanged<bool>? onChanged;

  const _LabelledSwitch({
    required this.label,
    required this.value,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: value,
            onChanged: disabled ? null : onChanged,
            activeThumbColor: AppTheme.primary,
          ),
        ),
        Text(
          disabled ? '$label (always)' : label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}
