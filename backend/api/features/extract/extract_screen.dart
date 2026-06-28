import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/export/care_record_pdf.dart';
import '../../core/inference/inference_provider.dart';
import 'extraction_service.dart';

/// Demonstrates the flagship privacy use case: paste a care note, get an
/// on-device summary + risk flags, with nothing sent to a server.
class ExtractScreen extends StatefulWidget {
  const ExtractScreen({super.key});

  @override
  State<ExtractScreen> createState() => _ExtractScreenState();
}

class _ExtractScreenState extends State<ExtractScreen> {
  final _controller = TextEditingController(
    text: 'Resident declined breakfast again this morning and seemed '
        'withdrawn. Complained of pain in left hip when transferring. '
        'Family visited briefly in the afternoon which lifted her mood.',
  );
  CareNoteAnalysis? _result;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyse() async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      // The provider exposes the active engine indirectly; here we build the
      // service against it. In a real app you'd inject this via Provider too.
      final provider = context.read<InferenceProvider>();
      final engine = provider.activeEngineOrThrow;
      final service = ExtractionService(engine);
      final analysis = await service.analyseCareNote(_controller.text.trim());
      setState(() => _result = analysis);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _exportPdf() async {
    final analysis = _result;
    if (analysis == null) return;
    final provider = context.read<InferenceProvider>();
    final checksum = await provider.activeModelChecksum() ?? 'unrecorded';
    final bytes = await CareRecordPdfBuilder().build(
      residentName: 'Sample Resident',
      recordId: DateTime.now().millisecondsSinceEpoch.toString(),
      originalNote: _controller.text.trim(),
      analysis: analysis,
      audit: PdfAuditInfo(
        modelName: provider.activeModel?.displayName ?? 'unknown',
        modelChecksum: checksum,
        generatedAt: DateTime.now(),
      ),
    );
    // Opens the OS share sheet; the PDF never leaves the device unless the
    // user explicitly shares it.
    await Printing.sharePdf(bytes: bytes, filename: 'care_record.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Care-note analysis (on-device)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Care note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _analyse,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_alt),
              label: Text(_busy ? 'Analysing…' : 'Analyse locally'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            if (_result != null) ...[
              _AnalysisCard(result: _result!),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export as PDF'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.result});

  final CareNoteAnalysis result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: Theme.of(context).textTheme.labelLarge),
            Text(result.summary),
            const SizedBox(height: 12),
            Row(
              children: [
                Chip(label: Text('Mood: ${result.mood}')),
                const SizedBox(width: 8),
                if (result.followUpRequired)
                  const Chip(
                    label: Text('Follow-up'),
                    avatar: Icon(Icons.flag, size: 18),
                  ),
              ],
            ),
            if (result.hasRisk) ...[
              const SizedBox(height: 12),
              Text('Risk flags',
                  style: Theme.of(context).textTheme.labelLarge),
              ...result.riskFlags.map(
                (f) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber, color: Colors.orange),
                  title: Text(f),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Decision support only — review by a senior carer required.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
