class ChcChecklist {
  final int id;
  final String status;
  final int countA;
  final int countB;
  final int countC;
  final String outcome;
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
    this.personInvolved = false,
    this.representativeName,
    this.representativeInvolved = false,
    this.assessorName,
    this.assessorRole,
    this.assessorOrg,
  });

  bool get isPositive => outcome == 'positive';
  bool get isCompleted => status == 'completed';

  factory ChcChecklist.fromJson(Map<String, dynamic> j) {
    Map<String, ChcDomain>? domains;
    if (j['domains'] is Map) {
      domains = (j['domains'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, ChcDomain.fromJson(v as Map<String, dynamic>)),
      );
    }
    return ChcChecklist(
      id: j['id'] as int,
      status: j['status'] as String? ?? 'draft',
      countA: (j['count_a'] as num?)?.toInt() ?? 0,
      countB: (j['count_b'] as num?)?.toInt() ?? 0,
      countC: (j['count_c'] as num?)?.toInt() ?? 0,
      outcome: j['outcome'] as String? ?? 'negative',
      completedAt: j['completed_at'] != null
          ? DateTime.tryParse((j['completed_at'] as String).replaceFirst(' ', 'T'))
          : null,
      createdAt: DateTime.parse((j['created_at'] as String).replaceFirst(' ', 'T')),
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
}

class ChcDomain {
  final String level;
  final String? evidence;

  const ChcDomain({required this.level, this.evidence});

  factory ChcDomain.fromJson(Map<String, dynamic> j) => ChcDomain(
        level: j['level'] as String? ?? 'C',
        evidence: j['evidence'] as String?,
      );
}
