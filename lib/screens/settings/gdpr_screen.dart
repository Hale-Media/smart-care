import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/resident.dart';
import '../../providers/auth_provider.dart';
import '../../services/gdpr_service.dart';
import '../../services/resident_service.dart';
import '../../widgets/common/loading_view.dart';

class GdprScreen extends StatefulWidget {
  const GdprScreen({super.key});

  @override
  State<GdprScreen> createState() => _GdprScreenState();
}

class _GdprScreenState extends State<GdprScreen> {
  final _residentService = ResidentService();
  final _gdprService = GdprService();
  final _jsonEncoder = const JsonEncoder.withIndent('  ');

  List<Resident> _residents = [];
  Resident? _selected;
  GdprExport? _export;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _loadResidents();
  }

  Future<void> _loadResidents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final residents = await _residentService.list(activeOnly: false);
      if (!mounted) return;
      setState(() {
        _residents = residents;
        _selected = residents.isEmpty ? null : residents.first;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_selected == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportResident() => _run(() async {
    final export = await _gdprService.exportResident(_selected!.id);
    if (mounted) {
      setState(() {
        _export = export;
        _notice = 'Subject access export generated.';
      });
    }
  });

  Future<void> _restrict(bool restricted) => _run(() async {
    if (restricted) {
      await _gdprService.restrict(_selected!.id);
    } else {
      await _gdprService.unrestrict(_selected!.id);
    }
    if (mounted) {
      setState(() {
        _notice = restricted
            ? 'Processing restriction recorded.'
            : 'Processing restriction lifted.';
      });
    }
  });

  Future<void> _erase() async {
    final confirmed = await _confirmErasure();
    if (confirmed != true) return;
    await _run(() async {
      await _gdprService.erase(_selected!.id);
      await _loadResidents();
      if (mounted) {
        setState(() {
          _export = null;
          _notice = 'Resident identifiers pseudonymised.';
        });
      }
    });
  }

  Future<bool?> _confirmErasure() {
    final controller = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pseudonymise resident?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This removes direct identifiers for ${_selected!.fullName}. Clinical and audit records are retained.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Type ERASE'),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(controller.text.trim().toUpperCase() == 'ERASE'),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyExport() async {
    final export = _export;
    if (export == null) return;
    await Clipboard.setData(
      ClipboardData(text: _jsonEncoder.convert(export.data)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Export copied')));
  }

  void _previewPdf() {
    final export = _export;
    if (export == null) return;
    final resident =
        (export.data['resident'] as Map?)?.cast<String, dynamic>() ?? {};
    final name =
        '${resident['first_name'] ?? 'Resident'} ${resident['last_name'] ?? ''}'
            .trim();
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SarPdfPreviewScreen(
          title: 'SAR — $name',
          filename: 'SAR_${name.replaceAll(' ', '_')}_$date.pdf',
          buildPdf: (_) => _buildSarPdf(export),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.role == StaffRole.admin;
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(title: const Text('Data protection')),
      body: _loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: _loadResidents,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_error != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                        ),
                        title: Text(_error!),
                      ),
                    ),
                  if (_notice != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(_notice!),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<Resident>(
                            initialValue: selected,
                            decoration: const InputDecoration(
                              labelText: 'Resident',
                              prefixIcon: Icon(Icons.person_search_outlined),
                            ),
                            items: _residents
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(
                                      '${r.fullName}${r.active ? '' : ' (discharged)'}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() {
                                    _selected = value;
                                    _export = null;
                                    _notice = null;
                                  }),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: selected == null || _busy
                                ? null
                                : _exportResident,
                            icon: _busy
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.file_download_outlined),
                            label: const Text('Generate subject access export'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.block_outlined,
                          title: 'Restrict processing',
                          subtitle:
                              'Record an Article 18 restriction for the selected resident',
                          buttonLabel: 'Restrict',
                          onPressed: selected == null || _busy
                              ? null
                              : () => _restrict(true),
                        ),
                        const Divider(height: 1),
                        _ActionTile(
                          icon: Icons.lock_open_outlined,
                          title: 'Lift restriction',
                          subtitle: 'Remove the processing restriction flag',
                          buttonLabel: 'Unrestrict',
                          onPressed: selected == null || _busy
                              ? null
                              : () => _restrict(false),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    child: _ActionTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Pseudonymise identifiers',
                      subtitle: isAdmin
                          ? selected != null && !selected.active
                                ? 'Admin only. Direct identifiers are removed; records are retained.'
                                : 'Only discharged residents can be pseudonymised.'
                          : 'Administrator role required.',
                      buttonLabel: 'Erase',
                      onPressed:
                          isAdmin &&
                              selected != null &&
                              !selected.active &&
                              !_busy
                          ? _erase
                          : null,
                    ),
                  ),
                  if (_export != null)
                    _ExportCard(
                      export: _export!,
                      onCopy: _copyExport,
                      onPreviewPdf: _busy ? null : _previewPdf,
                    ),
                ],
              ),
            ),
    );
  }
}

// ── Tiles ─────────────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: onPressed,
                    child: Text(buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final GdprExport export;
  final VoidCallback onCopy;
  final VoidCallback? onPreviewPdf;

  const _ExportCard({
    required this.export,
    required this.onCopy,
    this.onPreviewPdf,
  });

  @override
  Widget build(BuildContext context) {
    final generated = export.generatedAt == null
        ? 'Generated now'
        : 'Generated ${DateFormat('d MMM yyyy HH:mm').format(export.generatedAt!.toLocal())}';
    final text = const JsonEncoder.withIndent('  ').convert(export.data);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    generated,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy JSON',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: 'Preview PDF',
                  onPressed: onPreviewPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 420),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PDF preview screen ────────────────────────────────────────────────────────

class _SarPdfPreviewScreen extends StatelessWidget {
  final String title;
  final String filename;
  final LayoutCallback buildPdf;

  const _SarPdfPreviewScreen({
    required this.title,
    required this.filename,
    required this.buildPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: buildPdf,
        pdfFileName: filename,
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
      ),
    );
  }
}

// ── PDF builder ───────────────────────────────────────────────────────────────

Future<Uint8List> _buildSarPdf(GdprExport export) async {
  final doc = pw.Document();
  final resident =
      (export.data['resident'] as Map?)?.cast<String, dynamic>() ?? {};
  final residentName =
      '${resident['first_name'] ?? ''} ${resident['last_name'] ?? ''}'.trim();
  final generated = export.generatedAt != null
      ? DateFormat('d MMMM yyyy HH:mm').format(export.generatedAt!.toLocal())
      : DateFormat('d MMMM yyyy HH:mm').format(DateTime.now().toLocal());

  final body = <pw.Widget>[];

  for (final entry in export.data.entries) {
    body.add(pw.SizedBox(height: 12));
    body.add(
      pw.Text(
        _sarSectionTitle(entry.key),
        style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );
    body.add(pw.Divider(thickness: 0.5));

    final value = entry.value;
    if (value is Map) {
      body.addAll(_sarRows(Map<String, dynamic>.from(value)));
    } else if (value is List) {
      if (value.isEmpty) {
        body.add(
          pw.Text('No records.', style: const pw.TextStyle(fontSize: 9)),
        );
      }
      for (var i = 0; i < value.length; i++) {
        final record = value[i];
        if (record is! Map) continue;
        if (i > 0) {
          body.add(pw.Divider(thickness: 0.3, color: PdfColors.grey400));
        }
        body.add(
          pw.Text(
            'Record ${i + 1}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        );
        body.addAll(_sarRows(Map<String, dynamic>.from(record)));
      }
    }
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'SUBJECT ACCESS REPORT',
                style: const pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          pw.Text(
            'Resident: $residentName',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Generated: $generated — UK GDPR Article 15',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 1),
        ],
      ),
      build: (_) => body,
    ),
  );

  return doc.save();
}

List<pw.Widget> _sarRows(Map<String, dynamic> map) => map.entries
    .where((e) => e.value != null && '${e.value}'.isNotEmpty)
    .map(
      (e) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 130,
              child: pw.Text(
                _sarFormatKey(e.key),
                style: const pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                '${e.value}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    )
    .toList();

String _sarSectionTitle(String key) => key
    .split('_')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _sarFormatKey(String key) => key
    .split('_')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
