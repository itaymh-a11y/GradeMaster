import 'calculation_mode.dart';

enum MoedBPolicy {
  higher,
  moedB,
}

/// Recursive grade structure: a leaf holds a raw score and scale, or a branch holds
/// weighted children (weights are positive; they need not sum to 100%).
sealed class GradeNode {
  GradeNode({required this.id, required this.name});

  final String id;
  final String name;
}

/// Terminal component: [score] is on the `[0, maxScore]` scale of that assignment.
final class GradeLeaf extends GradeNode {
  GradeLeaf({
    required super.id,
    required super.name,
    required this.maxScore,
    this.score,
    this.bonusPoints = 0,
    this.moedBScore,
    this.isMoedBActive = false,
  }) : assert(maxScore > 0, 'maxScore must be positive');

  final double maxScore;
  final double? score;
  final double bonusPoints;
  final double? moedBScore;
  final bool isMoedBActive;
}

/// Non-terminal component: each child has a local [weight] (relative to siblings).
///
/// If [equalWeightChildren] is true, stored child weights are ignored for aggregation
/// and each direct child gets an equal share (1/n) of 100%.
final class GradeBranch extends GradeNode {
  GradeBranch({
    required super.id,
    required super.name,
    List<WeightedChild>? children,
    this.equalWeightChildren = false,
  }) : children = List<WeightedChild>.unmodifiable(children ?? const []);

  final List<WeightedChild> children;

  /// When true, children are aggregated with weight 1/n each (strict: all n; proportional: contributing only).
  final bool equalWeightChildren;
}

final class WeightedChild {
  WeightedChild({required this.weight, required this.node})
    : assert(weight >= 0, 'weight must be non-negative');

  final double weight;
  final GradeNode node;
}

/// Returns a **normalized** grade in `[0, 1]` (or beyond if raw score exceeds [maxScore]),
/// or `null` in [CalculationMode.proportional] when no score contributes anywhere in the subtree.
///
/// Manual weights are always normalized by Σw at each branch (so 1+1 ⇒ 50%/50%).
/// [GradeBranch.equalWeightChildren] uses 1/n (or 1/k in proportional among contributors).
///
/// All internal math uses [double]. Round to 2 decimals only in the UI.
double? computeNormalizedGrade(
  GradeNode node,
  CalculationMode mode, {
  MoedBPolicy moedBPolicy = MoedBPolicy.higher,
}) {
  return switch (mode) {
    CalculationMode.strict => _computeStrict(node, moedBPolicy: moedBPolicy),
    CalculationMode.proportional =>
      _computeProportional(node, moedBPolicy: moedBPolicy),
  };
}

double _computeStrict(GradeNode node, {required MoedBPolicy moedBPolicy}) {
  switch (node) {
    case final GradeLeaf leaf:
      final selectedScore = _selectedLeafScore(leaf, moedBPolicy);
      if (selectedScore == null) {
        return 0.0;
      }
      return selectedScore / leaf.maxScore + (leaf.bonusPoints / 100.0);

    case GradeBranch(:final children, :final equalWeightChildren):
      if (children.isEmpty) {
        return 0.0;
      }
      return _aggregateStrict(
        children,
        equalWeight: equalWeightChildren,
        moedBPolicy: moedBPolicy,
      );
  }
}

double? _computeProportional(
  GradeNode node, {
  required MoedBPolicy moedBPolicy,
}) {
  switch (node) {
    case final GradeLeaf leaf:
      final selectedScore = _selectedLeafScore(leaf, moedBPolicy);
      if (selectedScore == null) {
        return null;
      }
      return selectedScore / leaf.maxScore + (leaf.bonusPoints / 100.0);

    case GradeBranch(:final children, :final equalWeightChildren):
      if (children.isEmpty) {
        return null;
      }
      return _aggregateProportional(
        children,
        equalWeight: equalWeightChildren,
        moedBPolicy: moedBPolicy,
      );
  }
}

double _aggregateStrict(
  List<WeightedChild> children, {
  required bool equalWeight,
  required MoedBPolicy moedBPolicy,
}) {
  if (children.isEmpty) {
    return 0.0;
  }
  if (equalWeight) {
    final n = children.length;
    final wEach = 1.0 / n;
    var sum = 0.0;
    for (final wc in children) {
      sum += wEach * _computeStrict(wc.node, moedBPolicy: moedBPolicy);
    }
    return sum;
  }
  var sumW = 0.0;
  var sumWeighted = 0.0;
  for (final wc in children) {
    final g = _computeStrict(wc.node, moedBPolicy: moedBPolicy);
    sumW += wc.weight;
    sumWeighted += wc.weight * g;
  }
  if (sumW == 0.0) {
    return 0.0;
  }
  return sumWeighted / sumW;
}

double? _aggregateProportional(
  List<WeightedChild> children, {
  required bool equalWeight,
  required MoedBPolicy moedBPolicy,
}) {
  if (children.isEmpty) {
    return null;
  }
  if (equalWeight) {
    final gs = <double>[];
    for (final wc in children) {
      final g = _computeProportional(wc.node, moedBPolicy: moedBPolicy);
      if (g != null) {
        gs.add(g);
      }
    }
    if (gs.isEmpty) {
      return null;
    }
    final k = gs.length;
    return gs.reduce((a, b) => a + b) / k;
  }
  var sumW = 0.0;
  var sumWeighted = 0.0;
  for (final wc in children) {
    final g = _computeProportional(wc.node, moedBPolicy: moedBPolicy);
    if (g == null) {
      continue;
    }
    sumW += wc.weight;
    sumWeighted += wc.weight * g;
  }
  if (sumW == 0.0) {
    return null;
  }
  return sumWeighted / sumW;
}

double? _selectedLeafScore(GradeLeaf leaf, MoedBPolicy moedBPolicy) {
  if (!leaf.isMoedBActive || leaf.moedBScore == null) {
    return leaf.score;
  }
  final moedA = leaf.score;
  final moedB = leaf.moedBScore!;
  switch (moedBPolicy) {
    case MoedBPolicy.moedB:
      return moedB;
    case MoedBPolicy.higher:
      if (moedA == null) {
        return moedB;
      }
      return moedA >= moedB ? moedA : moedB;
  }
}
