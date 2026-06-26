class ChcDomain {
  final String level; // A | B | C
  final String? evidence;

  const ChcDomain({required this.level, this.evidence});

  factory ChcDomain.fromJson(Map<String, dynamic> j) => ChcDomain(
        level: j['level'] as String,
        evidence: j['evidence'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'level': level,
        if (evidence != null && evidence!.isNotEmpty) 'evidence': evidence,
      };
}

class ChcChecklist {
  final int id;
  final String status; // draft | completed
  final int countA;
  final int countB;
  final int countC;
  final String outcome; // positive | negative
  final DateTime? completedAt;
  final DateTime createdAt;
  final Map<String, ChcDomain>? domains;
  final String? rationale;
  final bool personInvolved;
  final String? representativeName;
  final bool representativeInvolved;
  final String? assessorName;
  final String? assessorRole;
  final String? assessorOrg;

  const ChcChecklist({
    required this.id,
    required this.status,
    required this.countA,
    required this.countB,
    required this.countC,
    required this.outcome,
    this.completedAt,
    required this.createdAt,
    this.domains,
    this.rationale,
    required this.personInvolved,
    this.representativeName,
    required this.representativeInvolved,
    this.assessorName,
    this.assessorRole,
    this.assessorOrg,
  });

  bool get isCompleted => status == 'completed';
  bool get isPositive => outcome == 'positive';

  factory ChcChecklist.fromJson(Map<String, dynamic> j) {
    final domainsRaw = j['domains'];
    Map<String, ChcDomain>? domains;
    if (domainsRaw is Map) {
      domains = domainsRaw.map(
        (k, v) => MapEntry(
          k as String,
          ChcDomain.fromJson(v as Map<String, dynamic>),
        ),
      );
    }
    return ChcChecklist(
      id: _i(j['id']),
      status: j['status'] as String? ?? 'draft',
      countA: _i(j['count_a']),
      countB: _i(j['count_b']),
      countC: _i(j['count_c']),
      outcome: j['outcome'] as String? ?? 'negative',
      completedAt: j['completed_at'] != null
          ? DateTime.parse(j['completed_at'] as String)
          : null,
      createdAt: j['created_at'] != null
          ? DateTime.parse(j['created_at'] as String)
          : DateTime.now(),
      domains: domains,
      rationale: j['rationale'] as String?,
      personInvolved: j['person_involved'] == 1 || j['person_involved'] == true,
      representativeName: j['representative_name'] as String?,
      representativeInvolved:
          j['representative_involved'] == 1 || j['representative_involved'] == true,
      assessorName: j['assessor_name'] as String?,
      assessorRole: j['assessor_role'] as String?,
      assessorOrg: j['assessor_org'] as String?,
    );
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
