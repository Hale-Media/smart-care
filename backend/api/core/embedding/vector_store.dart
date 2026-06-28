import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// One stored item: its source text, arbitrary metadata, and its embedding.
class VectorRecord {
  const VectorRecord({
    required this.id,
    required this.text,
    required this.vector,
    this.metadata = const {},
  });

  final String id;
  final String text;
  final List<double> vector;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'vector': vector,
        'metadata': metadata,
      };

  factory VectorRecord.fromJson(Map<String, dynamic> json) => VectorRecord(
        id: json['id'] as String,
        text: json['text'] as String,
        vector: (json['vector'] as List).map((e) => (e as num).toDouble()).toList(),
        metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// A record paired with its similarity to a query (1.0 = identical direction).
class ScoredRecord {
  const ScoredRecord(this.record, this.score);
  final VectorRecord record;
  final double score;
}

/// In-memory cosine-similarity vector store with optional JSON persistence.
///
/// Deliberately simple and runtime-agnostic. For a regulated product, the
/// vectors are derived from clinical text and must be treated as sensitive:
/// persist them inside your **encrypted SQLite** rather than the plaintext
/// JSON file used here for the reference implementation. A brute-force scan is
/// perfectly fine into the low thousands of records (a care home's volume); add
/// an ANN index (e.g. HNSW) only if you outgrow that.
class VectorStore {
  final List<VectorRecord> _records = [];

  int get length => _records.length;
  List<VectorRecord> get records => List.unmodifiable(_records);

  void add(VectorRecord record) {
    _records.removeWhere((r) => r.id == record.id); // upsert
    _records.add(record);
  }

  void addAll(Iterable<VectorRecord> records) => records.forEach(add);

  void removeById(String id) => _records.removeWhere((r) => r.id == id);

  void clear() => _records.clear();

  /// Return the [topK] records most similar to [query], filtered by
  /// [minScore]. Results are sorted best-first.
  List<ScoredRecord> search(
    List<double> query, {
    int topK = 5,
    double minScore = 0.0,
  }) {
    final scored = _records
        .map((r) => ScoredRecord(r, cosineSimilarity(query, r.vector)))
        .where((s) => s.score >= minScore)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList();
  }

  /// Cosine similarity in [-1, 1]. Returns 0 for zero/mismatched vectors rather
  /// than throwing, so a malformed embedding can't crash a search.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    var dot = 0.0, normA = 0.0, normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  // ── Persistence (reference only — encrypt at rest in production) ────────
  String toJsonString() =>
      jsonEncode(_records.map((r) => r.toJson()).toList());

  void loadFromJsonString(String json) {
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    _records
      ..clear()
      ..addAll(list.map(VectorRecord.fromJson));
  }

  Future<void> saveToFile(String path) async =>
      File(path).writeAsString(toJsonString());

  Future<void> loadFromFile(String path) async {
    final file = File(path);
    if (await file.exists()) loadFromJsonString(await file.readAsString());
  }
}
