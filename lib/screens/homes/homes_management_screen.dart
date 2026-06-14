import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/home.dart';
import '../../services/home_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';
import 'home_detail_screen.dart';

class HomesManagementScreen extends StatefulWidget {
  const HomesManagementScreen({super.key});
  @override
  State<HomesManagementScreen> createState() => _HomesManagementScreenState();
}

class _HomesManagementScreenState extends State<HomesManagementScreen> {
  final _service = HomeService();
  List<Home> _homes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _homes = await _service.list();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _confirmDelete(Home home) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete home?'),
        content: Text(
            '"${home.name}" will be permanently removed. This cannot be undone.'),
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
    if (confirmed != true) return false;
    try {
      await _service.delete(home.id);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      return false;
    }
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Add home'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Home name *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
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
                        await _service.create(
                          nameCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('$e')));
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
      appBar: AppBar(title: const Text('Homes')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_homes',
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add home'),
      ),
      body: _loading
          ? const LoadingView()
          : _homes.isEmpty
              ? const EmptyState(
                  icon: Icons.home_outlined,
                  title: 'No homes yet',
                  subtitle: 'Tap "Add home" to create your first care home.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                    itemCount: _homes.length,
                    itemBuilder: (_, i) {
                      final home = _homes[i];
                      return Dismissible(
                        key: Key('home_${home.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white),
                        ),
                        confirmDismiss: (_) => _confirmDelete(home),
                        onDismissed: (_) => _load(),
                        child: _HomeTile(home: home),
                      );
                    },
                  ),
                ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  final Home home;
  const _HomeTile({required this.home});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
          child: const Icon(Icons.home_outlined, color: AppTheme.primary),
        ),
        title: Text(home.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          home.residentCount == 1
              ? '1 resident'
              : '${home.residentCount} residents',
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => HomeDetailScreen(home: home)),
        ),
      ),
    );
  }
}
