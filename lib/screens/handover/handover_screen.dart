import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/handover_note.dart';
import '../../providers/auth_provider.dart';
import '../../services/handover_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_view.dart';

class HandoverScreen extends StatefulWidget {
  const HandoverScreen({super.key});
  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  final _service = HandoverService();
  List<HandoverNote> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _notes = await _service.list();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openWriteNote() async {
    final user = context.read<AuthProvider>().user;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _WriteNotePage(
          service: _service,
          staffId: user?.id ?? 0,
          staffName: user?.name ?? '',
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Handover note saved')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shift handover')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_handover',
        onPressed: _openWriteNote,
        icon: const Icon(Icons.edit),
        label: const Text('Write note'),
      ),
      body: _loading
          ? const LoadingView()
          : _notes.isEmpty
              ? const EmptyState(
                  icon: Icons.swap_horiz,
                  title: 'No handover notes',
                  subtitle: 'Tap Write note to leave a message for the next shift.')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: _notes.length,
                    itemBuilder: (_, i) => _tile(_notes[i]),
                  ),
                ),
    );
  }

  Widget _tile(HandoverNote note) {
    final shiftColor = _shiftColor(note.shift);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 5, color: shiftColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: shiftColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(note.shiftLabel,
                              style: TextStyle(
                                  color: shiftColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(note.createdLabel,
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12)),
                        ),
                        if (note.staffName != null)
                          Text(note.staffName!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(note.content, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _shiftColor(String shift) => switch (shift) {
        'am' => AppTheme.info,
        'pm' => AppTheme.warning,
        'night' => AppTheme.primaryDark,
        _ => AppTheme.primary,
      };
}

// ── Write note page ───────────────────────────────────────────────────────────

class _WriteNotePage extends StatefulWidget {
  final HandoverService service;
  final int staffId;
  final String staffName;
  const _WriteNotePage({
    required this.service,
    required this.staffId,
    required this.staffName,
  });
  @override
  State<_WriteNotePage> createState() => _WriteNotePageState();
}

class _WriteNotePageState extends State<_WriteNotePage> {
  final _content = TextEditingController();
  String _shift = _defaultShift();
  bool _saving = false;

  static String _defaultShift() {
    final h = DateTime.now().hour;
    if (h >= 7 && h < 14) return 'am';
    if (h >= 14 && h < 22) return 'pm';
    return 'night';
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_content.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please write a note')));
      return;
    }
    setState(() => _saving = true);
    final note = HandoverNote(
      id: 0,
      shift: _shift,
      content: _content.text.trim(),
      staffId: widget.staffId,
      createdAt: DateTime.now(),
    );
    try {
      await widget.service.create(note);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write handover note'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Signing off as: ${widget.staffName}',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _shift,
                  decoration: const InputDecoration(
                      labelText: 'Shift', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'am', child: Text('AM shift (07:00 – 14:00)')),
                    DropdownMenuItem(value: 'pm', child: Text('PM shift (14:00 – 22:00)')),
                    DropdownMenuItem(value: 'night', child: Text('Night shift (22:00 – 07:00)')),
                  ],
                  onChanged: (v) => setState(() => _shift = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _content,
                  decoration: const InputDecoration(
                    labelText: 'Handover note',
                    hintText:
                        'Key events, concerns, observations and actions for the next shift…',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 12,
                  autofocus: true,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: Text(_saving ? 'Saving…' : 'Save handover note'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
