// ignore_for_file: prefer_const_constructors

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/incident.dart';
import '../../models/resident.dart';
import '../../providers/auth_provider.dart';
import '../../services/incident_service.dart';
import '../../utils/validators.dart';

class IncidentFormScreen extends StatefulWidget {
  final Resident resident;
  const IncidentFormScreen({super.key, required this.resident});
  @override
  State<IncidentFormScreen> createState() => _IncidentFormScreenState();
}

class _IncidentFormScreenState extends State<IncidentFormScreen> {
  final _service = IncidentService();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _action = TextEditingController();
  final _location = TextEditingController();
  final _injuryDetails = TextEditingController();
  String _category = 'fall';
  String _severity = 'minor';
  bool _injury = false;
  bool _witnessed = false;
  bool _familyNotified = false;
  bool _gpNotified = false;
  bool _safeguarding = false;
  bool _cqc = false;
  bool _saving = false;
  String? _uploadStatus;
  final List<XFile> _photos = [];
  static const _maxPhotos = 5;

  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (xfile != null) setState(() => _photos.add(xfile));
  }

  Future<void> _showPhotoOptions() async {
    if (_photos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $_maxPhotos photos allowed')),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _uploadStatus = null;
    });

    final staffId = context.read<AuthProvider>().user?.id ?? 0;
    final now = DateTime.now();

    // Upload photos first, then submit incident with the returned URLs.
    final photoUrls = <String>[];
    for (var i = 0; i < _photos.length; i++) {
      setState(
        () => _uploadStatus = 'Uploading photo ${i + 1}/${_photos.length}…',
      );
      try {
        photoUrls.add(await _service.uploadPhoto(_photos[i]));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
          setState(() {
            _saving = false;
            _uploadStatus = null;
          });
        }
        return;
      }
    }

    if (mounted) setState(() => _uploadStatus = 'Saving incident…');

    final incident = Incident(
      id: 0,
      residentId: widget.resident.id,
      category: _category,
      severity: _severity,
      occurredAt: now,
      reportedAt: now,
      reportedByStaffId: staffId,
      location: _location.text.trim(),
      description: _description.text.trim(),
      immediateAction: _action.text.trim(),
      injurySustained: _injury,
      injuryDetails: _injury ? _injuryDetails.text.trim() : null,
      witnessed: _witnessed,
      familyNotified: _familyNotified,
      gpNotified: _gpNotified,
      safeguardingRaised: _safeguarding,
      cqcNotifiable: _cqc,
      photoUrls: photoUrls,
    );

    try {
      await _service.create(incident);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
        setState(() {
          _saving = false;
          _uploadStatus = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _action.dispose();
    _location.dispose();
    _injuryDetails.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Incident · ${widget.resident.firstName}')),
      bottomNavigationBar: SafeArea(
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
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Log incident'),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                'fall',
                'injury',
                'medication_error',
                'safeguarding',
                'behaviour',
                'near_miss',
                'other',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: const [
                'minor',
                'moderate',
                'major',
                'catastrophic',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _severity = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'What happened?'),
              maxLines: 4,
              validator: (v) => Validators.required(v, 'Description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _action,
              decoration: const InputDecoration(
                labelText: 'Immediate action taken',
              ),
              maxLines: 3,
            ),
            SwitchListTile(
              value: _injury,
              onChanged: (v) => setState(() => _injury = v),
              title: const Text('Injury sustained'),
            ),
            if (_injury) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _injuryDetails,
                decoration: const InputDecoration(labelText: 'Injury details'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
            ],
            // ── Photo documentation ───────────────────────────────
            _PhotoPicker(
              photos: _photos,
              maxPhotos: _maxPhotos,
              onAdd: _showPhotoOptions,
              onRemove: (i) => setState(() => _photos.removeAt(i)),
            ),
            // ── Notification / compliance toggles ─────────────────
            SwitchListTile(
              value: _witnessed,
              onChanged: (v) => setState(() => _witnessed = v),
              title: const Text('Witnessed'),
            ),
            SwitchListTile(
              value: _familyNotified,
              onChanged: (v) => setState(() => _familyNotified = v),
              title: const Text('Family / next of kin notified'),
            ),
            SwitchListTile(
              value: _gpNotified,
              onChanged: (v) => setState(() => _gpNotified = v),
              title: const Text('GP notified'),
            ),
            SwitchListTile(
              value: _safeguarding,
              onChanged: (v) => setState(() => _safeguarding = v),
              title: const Text('Safeguarding referral raised'),
            ),
            SwitchListTile(
              value: _cqc,
              onChanged: (v) => setState(() => _cqc = v),
              title: const Text('CQC notifiable'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo picker widget ───────────────────────────────────────────────────────

class _PhotoPicker extends StatelessWidget {
  final List<XFile> photos;
  final int maxPhotos;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _PhotoPicker({
    required this.photos,
    required this.maxPhotos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Photos',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${photos.length}/$maxPhotos',
                style: const TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...List.generate(photos.length, _thumb),
                if (photos.length < maxPhotos) _addButton(),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _thumb(int i) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(photos[i].path),
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => onRemove(i),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _addButton() => GestureDetector(
    onTap: onAdd,
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
          Text(
            'Add photo',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    ),
  );
}
