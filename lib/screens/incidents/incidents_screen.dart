import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/incident.dart';
import '../../models/resident.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resident_provider.dart';
import '../../services/incident_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import 'incident_form_screen.dart';

/// Home-wide incident list with optional per-resident filtering.
class IncidentsScreen extends StatefulWidget {
  final int? residentId;
  const IncidentsScreen({super.key, this.residentId});
  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  final _service = IncidentService();
  List<Incident> _incidents = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter; // null = all
  int? _lastHomeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _incidents = await _service.list(
        status: _statusFilter,
        residentId: widget.residentId,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openLogForm() async {
    final residents = context.read<ResidentProvider>().residents;
    if (residents.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No residents loaded')));
      return;
    }

    Resident? picked;
    if (residents.length == 1) {
      picked = residents.first;
    } else {
      picked = await showDialog<Resident>(
        context: context,
        builder: (_) => _ResidentPickerDialog(residents: residents),
      );
    }
    if (picked == null || !mounted) return;

    final logged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => IncidentFormScreen(resident: picked!)),
    );
    if (logged == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Incident logged')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeId = context.select<AuthProvider, int?>((a) => a.activeHomeId);
    if (_lastHomeId != null && homeId != _lastHomeId) {
      _lastHomeId = homeId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    } else {
      _lastHomeId ??= homeId;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _filterBar(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_incidents',
        onPressed: _openLogForm,
        icon: const Icon(Icons.add),
        label: const Text('Log incident'),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _incidents.isEmpty
                  ? const EmptyState(
                      icon: Icons.report_problem_outlined,
                      title: 'No incidents',
                      subtitle: 'Logged incidents will appear here.')
                  : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: _incidents.length,
                    itemBuilder: (_, i) => _tile(_incidents[i]),
                  ),
                ),
    );
  }

  Widget _filterBar() {
    final filters = <String?>[null, 'open', 'investigating', 'closed'];
    final labels = ['All', 'Open', 'Investigating', 'Closed'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: List.generate(filters.length, (i) {
          final selected = _statusFilter == filters[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[i]),
              selected: selected,
              onSelected: (_) {
                setState(() => _statusFilter = filters[i]);
                _load();
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _tile(Incident inc) {
    final severityColor = _severityColor(inc.severity);
    final statusColor = _statusColor(inc.status);
    final fmt = DateFormat('d MMM yyyy, HH:mm');
    final reporterPart =
        inc.reportedByName != null ? ' by ${inc.reportedByName}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    _IncidentDetailPage(incident: inc, service: _service)),
          );
          _load();
        },
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: severityColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${inc.residentName ?? 'Resident'} · ${inc.category}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                          _chip(inc.severity, severityColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fmt.format(inc.occurredAt.toLocal())}$reporterPart',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _chip(inc.status, statusColor),
                          if (inc.cqcNotifiable) ...[
                            const SizedBox(width: 6),
                            _chip('CQC', AppTheme.critical),
                          ],
                          if (inc.safeguardingRaised) ...[
                            const SizedBox(width: 6),
                            _chip('Safeguarding', Colors.purple),
                          ],
                          if (inc.injurySustained) ...[
                            const SizedBox(width: 6),
                            _chip('Injury', AppTheme.warning),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Colors.black26, size: 20),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Color _severityColor(String s) => switch (s) {
        'catastrophic' => AppTheme.critical,
        'major' => AppTheme.critical,
        'moderate' => AppTheme.warning,
        _ => Colors.grey,
      };

  Color _statusColor(String s) => switch (s) {
        'open' => AppTheme.warning,
        'investigating' => AppTheme.primary,
        'closed' => AppTheme.ok,
        _ => Colors.grey,
      };
}

// ── Incident detail + status update ──────────────────────────────────────────

class _IncidentDetailPage extends StatefulWidget {
  final Incident incident;
  final IncidentService service;
  const _IncidentDetailPage({required this.incident, required this.service});
  @override
  State<_IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<_IncidentDetailPage> {
  late Incident _inc;
  bool _saving = false;
  bool _editing = false;
  String? _uploadStatus;

  // Edit-mode state
  final _descCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  final _injuryDetailsCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _editInjury = false;
  bool _editFamilyNotified = false;
  bool _editGpNotified = false;
  List<String> _editPhotoUrls = [];
  final List<XFile> _editNewPhotos = [];
  final _picker = ImagePicker();
  static const _maxPhotos = 5;

  @override
  void initState() {
    super.initState();
    _inc = widget.incident;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _actionCtrl.dispose();
    _injuryDetailsCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _startEdit() {
    _descCtrl.text = _inc.description;
    _actionCtrl.text = _inc.immediateAction ?? '';
    _injuryDetailsCtrl.text = _inc.injuryDetails ?? '';
    _locationCtrl.text = _inc.location ?? '';
    _editInjury = _inc.injurySustained;
    _editFamilyNotified = _inc.familyNotified;
    _editGpNotified = _inc.gpNotified;
    _editPhotoUrls = List.from(_inc.photoUrls);
    _editNewPhotos.clear();
    setState(() => _editing = true);
  }

  void _cancelEdit() => setState(() {
        _editing = false;
        _uploadStatus = null;
      });

  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (xfile != null) setState(() => _editNewPhotos.add(xfile));
  }

  Future<void> _showPhotoOptions() async {
    final total = _editPhotoUrls.length + _editNewPhotos.length;
    if (total >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum $_maxPhotos photos allowed')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEdit() async {
    setState(() {
      _saving = true;
      _uploadStatus = null;
    });

    final allUrls = List<String>.from(_editPhotoUrls);
    for (var i = 0; i < _editNewPhotos.length; i++) {
      setState(
        () => _uploadStatus = 'Uploading photo ${i + 1}/${_editNewPhotos.length}…',
      );
      try {
        allUrls.add(await widget.service.uploadPhoto(_editNewPhotos[i]));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
          setState(() {
            _saving = false;
            _uploadStatus = null;
          });
        }
        return;
      }
    }

    if (mounted) setState(() => _uploadStatus = 'Saving…');

    try {
      final updated = await widget.service.update(
        Incident(
          id: _inc.id,
          residentId: _inc.residentId,
          category: _inc.category,
          severity: _inc.severity,
          occurredAt: _inc.occurredAt,
          reportedAt: _inc.reportedAt,
          reportedByStaffId: _inc.reportedByStaffId,
          description: _descCtrl.text.trim(),
          immediateAction: _actionCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          injurySustained: _editInjury,
          injuryDetails: _editInjury ? _injuryDetailsCtrl.text.trim() : null,
          familyNotified: _editFamilyNotified,
          gpNotified: _editGpNotified,
          witnessed: _inc.witnessed,
          cqcNotifiable: _inc.cqcNotifiable,
          safeguardingRaised: _inc.safeguardingRaised,
          photoUrls: allUrls,
          status: _inc.status,
        ),
      );
      if (mounted) {
        setState(() {
          _inc = updated;
          _editing = false;
          _saving = false;
          _uploadStatus = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        setState(() {
          _saving = false;
          _uploadStatus = null;
        });
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _saving = true);
    try {
      final updated = await widget.service.update(
        Incident(
          id: _inc.id,
          residentId: _inc.residentId,
          category: _inc.category,
          severity: _inc.severity,
          occurredAt: _inc.occurredAt,
          reportedAt: _inc.reportedAt,
          reportedByStaffId: _inc.reportedByStaffId,
          description: _inc.description,
          photoUrls: _inc.photoUrls,
          status: status,
        ),
      );
      if (mounted) setState(() => _inc = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showPhoto(BuildContext ctx, String url) {
    showDialog<void>(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
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
        title: Text(_editing ? 'Edit incident' : (_inc.residentName ?? 'Incident')),
        leading: _editing
            ? TextButton(
                onPressed: _saving ? null : _cancelEdit,
                child: const Text('Cancel'),
              )
            : const BackButton(),
        actions: _editing
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: _startEdit,
                ),
              ],
      ),
      bottomNavigationBar: _editing
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_uploadStatus != null) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 6),
                      Text(
                        _uploadStatus!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      onPressed: _saving ? null : _saveEdit,
                      child: Text(_saving ? 'Saving…' : 'Update'),
                    ),
                  ],
                ),
              ),
            )
          : (_inc.status != 'closed'
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(children: [
                      if (_inc.status == 'open') ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _updateStatus('investigating'),
                            child: const Text('Mark investigating'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              _saving ? null : () => _updateStatus('closed'),
                          child: const Text('Close incident'),
                        ),
                      ),
                    ]),
                  ),
                )
              : null),
      body: _editing ? _buildEditBody() : _buildViewBody(context),
    );
  }

  Widget _buildViewBody(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy, HH:mm');
    final severityColor = _severityColor(_inc.severity);
    final statusColor = _statusColor(_inc.status);
    final reporterPart =
        _inc.reportedByName != null ? ' by ${_inc.reportedByName}' : '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 8, runSpacing: 6, children: [
          _chip(_inc.category, Colors.blueGrey),
          _chip(_inc.severity, severityColor),
          _chip(_inc.status, statusColor),
          if (_inc.cqcNotifiable) _chip('CQC notifiable', AppTheme.critical),
          if (_inc.safeguardingRaised) _chip('Safeguarding', Colors.purple),
          if (_inc.injurySustained) _chip('Injury sustained', AppTheme.warning),
          if (_inc.witnessed) _chip('Witnessed', Colors.teal),
        ]),
        const SizedBox(height: 16),
        _row('Occurred', fmt.format(_inc.occurredAt.toLocal())),
        _row('Reported', '${fmt.format(_inc.reportedAt.toLocal())}$reporterPart'),
        if (_inc.location != null && _inc.location!.isNotEmpty)
          _row('Location', _inc.location!),
        const Divider(height: 24),
        _section('What happened', _inc.description),
        if (_inc.immediateAction != null && _inc.immediateAction!.isNotEmpty)
          _section('Immediate action', _inc.immediateAction!),
        if (_inc.injuryDetails != null && _inc.injuryDetails!.isNotEmpty)
          _section('Injury details', _inc.injuryDetails!),
        if (_inc.photoUrls.isNotEmpty) ...[
          const Text(
            'Photos',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _inc.photoUrls.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _showPhoto(ctx, _inc.photoUrls[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _inc.photoUrls[i],
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _row('Family notified', _inc.familyNotified ? 'Yes' : 'No'),
        _row('GP notified', _inc.gpNotified ? 'Yes' : 'No'),
        if (_inc.status == 'closed') ...[
          const SizedBox(height: 16),
          _chip('Incident closed', AppTheme.ok),
        ],
      ],
    );
  }

  Widget _buildEditBody() {
    final total = _editPhotoUrls.length + _editNewPhotos.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _descCtrl,
          decoration: const InputDecoration(labelText: 'What happened?'),
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _actionCtrl,
          decoration: const InputDecoration(labelText: 'Immediate action taken'),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _locationCtrl,
          decoration: const InputDecoration(labelText: 'Location'),
        ),
        SwitchListTile(
          value: _editInjury,
          onChanged: (v) => setState(() => _editInjury = v),
          title: const Text('Injury sustained'),
        ),
        if (_editInjury) ...[
          TextFormField(
            controller: _injuryDetailsCtrl,
            decoration: const InputDecoration(labelText: 'Injury details'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
        ],
        // Photo management
        Row(children: [
          const Text(
            'Photos',
            style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Text(
            '$total/$_maxPhotos',
            style: const TextStyle(fontSize: 12, color: Colors.black38),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._editPhotoUrls.asMap().entries.map((e) => _networkThumb(e.key, e.value)),
              ..._editNewPhotos.asMap().entries.map((e) => _localThumb(e.key, e.value)),
              if (total < _maxPhotos) _addButton(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _editFamilyNotified,
          onChanged: (v) => setState(() => _editFamilyNotified = v),
          title: const Text('Family / next of kin notified'),
        ),
        SwitchListTile(
          value: _editGpNotified,
          onChanged: (v) => setState(() => _editGpNotified = v),
          title: const Text('GP notified'),
        ),
      ],
    );
  }

  Widget _networkThumb(int i, String url) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            _removeBtn(() => setState(() => _editPhotoUrls.removeAt(i))),
          ],
        ),
      );

  Widget _localThumb(int i, XFile file) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(file.path),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            _removeBtn(() => setState(() => _editNewPhotos.removeAt(i))),
          ],
        ),
      );

  Widget _removeBtn(VoidCallback onTap) => Positioned(
        top: 4,
        right: 4,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            padding: const EdgeInsets.all(2),
            child: const Icon(Icons.close, size: 14, color: Colors.white),
          ),
        ),
      );

  Widget _addButton() => GestureDetector(
        onTap: _showPhotoOptions,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black26),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 28, color: Colors.black45),
              SizedBox(height: 4),
              Text('Add photo',
                  style: TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          ),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.black54, fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Widget _section(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 15)),
          ],
        ),
      );

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );

  Color _severityColor(String s) => switch (s) {
        'catastrophic' || 'major' => AppTheme.critical,
        'moderate' => AppTheme.warning,
        _ => Colors.grey,
      };

  Color _statusColor(String s) => switch (s) {
        'open' => AppTheme.warning,
        'investigating' => AppTheme.primary,
        'closed' => AppTheme.ok,
        _ => Colors.grey,
      };
}

// ── Resident picker dialog ────────────────────────────────────────────────────

class _ResidentPickerDialog extends StatelessWidget {
  final List<Resident> residents;
  const _ResidentPickerDialog({required this.residents});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Select resident'),
      children: residents
          .map((r) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, r),
                child: Text(r.fullName),
              ))
          .toList(),
    );
  }
}
