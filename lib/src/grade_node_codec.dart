import 'grade_node.dart';

const String _kLeaf = 'leaf';
const String _kBranch = 'branch';

/// JSON-safe encoding for Firestore (maps and lists only).
Map<String, dynamic> gradeNodeToMap(GradeNode node) {
  switch (node) {
    case GradeLeaf(
      :final id,
      :final name,
      :final maxScore,
      :final score,
      :final bonusPoints,
      :final moedBScore,
      :final isMoedBActive,
    ):
      return <String, dynamic>{
        'type': _kLeaf,
        'id': id,
        'name': name,
        'maxScore': maxScore,
        'score': score,
        'bonusPoints': bonusPoints,
        'moedBScore': moedBScore,
        'isMoedBActive': isMoedBActive,
      };
    case GradeBranch(
      :final id,
      :final name,
      :final children,
      :final equalWeightChildren,
    ):
      return <String, dynamic>{
        'type': _kBranch,
        'id': id,
        'name': name,
        'equalWeightChildren': equalWeightChildren,
        'children': children
            .map(
              (c) => <String, dynamic>{
                'weight': c.weight,
                'node': gradeNodeToMap(c.node),
              },
            )
            .toList(),
      };
  }
}

GradeNode gradeNodeFromMap(Map<String, dynamic> raw) {
  final type = raw['type'] as String?;
  if (type == _kLeaf) {
    final scoreRaw = raw['score'];
    return GradeLeaf(
      id: raw['id']! as String,
      name: raw['name']! as String,
      maxScore: (raw['maxScore'] as num).toDouble(),
      score: scoreRaw == null ? null : (scoreRaw as num).toDouble(),
      bonusPoints: (raw['bonusPoints'] as num?)?.toDouble() ?? 0,
      moedBScore: (raw['moedBScore'] as num?)?.toDouble(),
      isMoedBActive: raw['isMoedBActive'] as bool? ?? false,
    );
  }
  if (type == _kBranch) {
    final childrenRaw = raw['children'] as List<dynamic>? ?? const [];
    final children = <WeightedChild>[];
    for (final item in childrenRaw) {
      final m = Map<String, dynamic>.from(item as Map);
      children.add(
        WeightedChild(
          weight: (m['weight'] as num).toDouble(),
          node: gradeNodeFromMap(Map<String, dynamic>.from(m['node'] as Map)),
        ),
      );
    }
    final eq = raw['equalWeightChildren'] as bool? ?? false;
    return GradeBranch(
      id: raw['id']! as String,
      name: raw['name']! as String,
      children: children,
      equalWeightChildren: eq,
    );
  }
  throw FormatException('Unknown GradeNode type: $type');
}

/// Independent copy of the tree (safe before mutating a user copy).
GradeNode deepCopyGradeNode(GradeNode node) {
  return gradeNodeFromMap(gradeNodeToMap(node));
}

/// Strips scores and Moed B state so a [Course] editor state can be stored as a public template.
GradeNode stripScoresForTemplate(GradeNode node) {
  return switch (node) {
    GradeLeaf(:final id, :final name, :final maxScore) => GradeLeaf(
      id: id,
      name: name,
      maxScore: maxScore,
    ),
    GradeBranch(
      :final id,
      :final name,
      :final equalWeightChildren,
      :final children,
    ) =>
      GradeBranch(
        id: id,
        name: name,
        equalWeightChildren: equalWeightChildren,
        children: [
          for (final wc in children)
            WeightedChild(
              weight: wc.weight,
              node: stripScoresForTemplate(wc.node),
            ),
        ],
      ),
  };
}

/// Default empty tree for a new course (strict → 0%, proportional → no data).
GradeNode emptyCourseRootNode() {
  return GradeBranch(id: 'root', name: 'שורש', children: const []);
}

/// Root for quick final-grade input: one direct 100-point leaf.
GradeNode fastGradingRootNode() {
  return GradeBranch(
    id: 'root',
    name: 'שורש',
    children: [
      WeightedChild(
        weight: 100,
        node: GradeLeaf(id: 'final_grade', name: 'ציון סופי', maxScore: 100),
      ),
    ],
  );
}
