import 'dart:convert';

import '../../core/inference/inference_engine.dart';

/// Turns free text into structured, typed data entirely on-device.
///
/// This is the use case that justifies on-device AI in a regulated vertical:
/// a care note, a clinical observation, an incident report is summarised and
/// risk-flagged WITHOUT a single byte leaving the handset. The same pattern
/// covers triage tagging, document classification, redaction prep, etc.
///
/// Small models are unreliable free-form but surprisingly good at "read this
/// and fill in these fields" when constrained hard. The trick is a strict
/// prompt + defensive parsing, because a 270M model WILL occasionally wrap its
/// JSON in prose or a code fence.
class ExtractionService {
  ExtractionService(this._engine);

  final InferenceEngine _engine;

  /// Extract structured fields from [text] given a [schema] describing the
  /// fields to return. Returns a decoded map, or throws [InferenceException]
  /// if the model could not be coerced into valid JSON after [maxRetries].
  Future<Map<String, dynamic>> extract({
    required String text,
    required Map<String, String> schema,
    int maxRetries = 2,
  }) async {
    final fieldList = schema.entries
        .map((e) => '  "${e.key}": <${e.value}>')
        .join(',\n');

    final prompt = '''
You are a data extraction function. Read the INPUT and return ONLY a JSON
object matching the SCHEMA exactly. Do not add commentary, explanation, or
markdown fences. If a value is not present in the input, use null.

SCHEMA:
{
$fieldList
}

INPUT:
"""
$text
"""

JSON:''';

    InferenceException? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final raw = await _engine.generate(prompt);
      final parsed = _tryParse(raw);
      if (parsed != null) return parsed;
      lastError = InferenceException(
        'Model did not return valid JSON (attempt ${attempt + 1})',
      );
      await _engine.resetSession();
    }
    throw lastError ?? InferenceException('Extraction failed');
  }

  /// Convenience: care-note risk triage. Returns a summary plus structured
  /// risk flags suitable for surfacing to a senior carer for review.
  ///
  /// NB: on a CQC-regulated product this is a decision-SUPPORT aid, not a
  /// decision-maker. Always keep a human in the loop and log the model version.
  Future<CareNoteAnalysis> analyseCareNote(String note) async {
    final result = await extract(
      text: note,
      schema: {
        'summary': 'one-sentence plain-English summary',
        'mood': 'one of: positive, neutral, low, distressed, unknown',
        'risk_flags':
            'array of short strings for any safeguarding/clinical concerns',
        'follow_up_required': 'boolean',
      },
    );

    return CareNoteAnalysis(
      summary: (result['summary'] as String?)?.trim() ?? '',
      mood: (result['mood'] as String?)?.trim() ?? 'unknown',
      riskFlags: (result['risk_flags'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      followUpRequired: result['follow_up_required'] == true,
    );
  }

  /// Pull the first balanced JSON object out of a possibly-noisy completion.
  Map<String, dynamic>? _tryParse(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();

    final start = cleaned.indexOf('{');
    if (start == -1) return null;

    var depth = 0;
    for (var i = start; i < cleaned.length; i++) {
      final ch = cleaned[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          final candidate = cleaned.substring(start, i + 1);
          try {
            final decoded = jsonDecode(candidate);
            return decoded is Map<String, dynamic> ? decoded : null;
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }
}

/// Typed result of [ExtractionService.analyseCareNote].
class CareNoteAnalysis {
  const CareNoteAnalysis({
    required this.summary,
    required this.mood,
    required this.riskFlags,
    required this.followUpRequired,
  });

  final String summary;
  final String mood;
  final List<String> riskFlags;
  final bool followUpRequired;

  bool get hasRisk => riskFlags.isNotEmpty;
}
