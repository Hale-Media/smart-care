import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/extract/extraction_service.dart';

/// Audit metadata stamped onto every exported record so you can prove, after
/// the fact, exactly which model produced a given analysis. On a CQC-regulated
/// product this is the difference between "the AI flagged it" and an auditable
/// record.
class PdfAuditInfo {
  const PdfAuditInfo({
    required this.modelName,
    required this.modelChecksum,
    required this.generatedAt,
    this.author,
  });

  final String modelName;
  final String modelChecksum; // SHA-256 from ModelManager.recordedChecksum
  final DateTime generatedAt;
  final String? author;
}

/// Builds a clinician-readable PDF from a [CareNoteAnalysis]. Returns the raw
/// bytes — caller decides whether to save, share, or print (via `printing`).
///
/// Layout mirrors a Smart Care record: header band, resident/record meta,
/// the original note, the on-device analysis, then a locked audit footer.
class CareRecordPdfBuilder {
  static const PdfColor _teal = PdfColor.fromInt(0xFF0F766E);
  static const PdfColor _amber = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor _slate = PdfColor.fromInt(0xFF334155);

  Future<Uint8List> build({
    required String residentName,
    required String recordId,
    required String originalNote,
    required CareNoteAnalysis analysis,
    required PdfAuditInfo audit,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(residentName, recordId),
            pw.SizedBox(height: 20),
            _sectionLabel('Original note'),
            pw.Text(originalNote, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),
            _sectionLabel('On-device analysis'),
            _analysisBlock(analysis),
            pw.Spacer(),
            _auditFooter(audit),
          ],
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _header(String residentName, String recordId) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(color: _teal),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Care Record',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                residentName,
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 13),
              ),
            ],
          ),
          pw.Text(
            'Record $recordId',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionLabel(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      text.toUpperCase(),
      style: const pw.TextStyle(
        fontSize: 9,
        letterSpacing: 1.2,
        color: _slate,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );

  pw.Widget _analysisBlock(CareNoteAnalysis analysis) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF1F5F9),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            analysis.summary,
            style: const pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _pill('Mood: ${analysis.mood}', _slate),
              pw.SizedBox(width: 8),
              if (analysis.followUpRequired)
                _pill('Follow-up required', _amber),
            ],
          ),
          if (analysis.hasRisk) ...[
            pw.SizedBox(height: 12),
            _sectionLabel('Risk flags'),
            ...analysis.riskFlags.map(
              (f) => pw.Bullet(
                text: f,
                style: const pw.TextStyle(fontSize: 11),
                bulletColor: _amber,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _pill(String text, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: color),
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 9, color: color)),
  );

  pw.Widget _auditFooter(PdfAuditInfo audit) {
    final ts = audit.generatedAt.toIso8601String();
    final shortHash = audit.modelChecksum.length > 16
        ? '${audit.modelChecksum.substring(0, 16)}…'
        : audit.modelChecksum;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Generated on-device — no data left this device. '
            'Decision support only; clinical judgement required.',
            style: const pw.TextStyle(
              fontSize: 8,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Model: ${audit.modelName} · SHA-256 $shortHash · '
            '${audit.author != null ? 'Reviewed by ${audit.author} · ' : ''}'
            'Generated $ts',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }
}
