class ChcSummary {
  final int positivePending;
  final int totalDrafts;

  const ChcSummary({required this.positivePending, required this.totalDrafts});

  factory ChcSummary.fromJson(Map<String, dynamic> j) => ChcSummary(
        positivePending: (j['positive_pending'] as num?)?.toInt() ?? 0,
        totalDrafts: (j['total_drafts'] as num?)?.toInt() ?? 0,
      );
}
