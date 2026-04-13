import 'package:flutter_test/flutter_test.dart';
import 'package:grade_master/grade_master.dart';

void main() {
  group('GradeLeaf', () {
    test('strict: missing score is 0', () {
      final leaf = GradeLeaf(id: 'a', name: 'Quiz', maxScore: 10, score: null);
      expect(computeNormalizedGrade(leaf, CalculationMode.strict), 0.0);
    });

    test('proportional: missing score is null', () {
      final leaf = GradeLeaf(id: 'a', name: 'Quiz', maxScore: 10, score: null);
      expect(computeNormalizedGrade(leaf, CalculationMode.proportional), isNull);
    });

    test('score normalized by maxScore', () {
      final leaf = GradeLeaf(id: 'a', name: 'Exam', maxScore: 100, score: 85);
      expect(computeNormalizedGrade(leaf, CalculationMode.strict), closeTo(0.85, 1e-12));
    });

    test('leaf bonus points are added after normalization', () {
      final leaf = GradeLeaf(
        id: 'a',
        name: 'Exam',
        maxScore: 100,
        score: 85,
        bonusPoints: 2,
      );
      expect(computeNormalizedGrade(leaf, CalculationMode.strict), closeTo(0.87, 1e-12));
    });
  });

  group('GradeBranch strict', () {
    test('missing leaf counts as 0; denominator is sum of weights', () {
      final tree = GradeBranch(
        id: 'root',
        name: 'Course',
        children: [
          WeightedChild(
            weight: 30,
            node: GradeLeaf(id: 'a', name: 'A', maxScore: 100, score: 50),
          ),
          WeightedChild(
            weight: 70,
            node: GradeLeaf(id: 'b', name: 'B', maxScore: 100, score: null),
          ),
        ],
      );
      // (30*0.5 + 70*0) / 100 = 0.15
      expect(
        computeNormalizedGrade(tree, CalculationMode.strict),
        closeTo(0.15, 1e-12),
      );
    });

    test('weights need not sum to 100', () {
      final tree = GradeBranch(
        id: 'root',
        name: 'Course',
        children: [
          WeightedChild(
            weight: 1,
            node: GradeLeaf(id: 'a', name: 'A', maxScore: 10, score: 10),
          ),
          WeightedChild(
            weight: 1,
            node: GradeLeaf(id: 'b', name: 'B', maxScore: 10, score: 0),
          ),
        ],
      );
      expect(computeNormalizedGrade(tree, CalculationMode.strict), closeTo(0.5, 1e-12));
    });

    test('empty branch is 0', () {
      final tree = GradeBranch(id: 'root', name: 'Empty', children: []);
      expect(computeNormalizedGrade(tree, CalculationMode.strict), 0.0);
    });

    test('all zero weights yields 0', () {
      final tree = GradeBranch(
        id: 'root',
        name: 'Course',
        children: [
          WeightedChild(
            weight: 0,
            node: GradeLeaf(id: 'a', name: 'A', maxScore: 100, score: 100),
          ),
        ],
      );
      expect(computeNormalizedGrade(tree, CalculationMode.strict), 0.0);
    });

    test('equalWeightChildren ignores stored weights (1/n strict)', () {
      final tree = GradeBranch(
        id: 'root',
        name: 'Labs',
        equalWeightChildren: true,
        children: [
          WeightedChild(
            weight: 100,
            node: GradeLeaf(id: 'a', name: 'A', maxScore: 100, score: 100),
          ),
          WeightedChild(
            weight: 1,
            node: GradeLeaf(id: 'b', name: 'B', maxScore: 100, score: 0),
          ),
        ],
      );
      expect(computeNormalizedGrade(tree, CalculationMode.strict), closeTo(0.5, 1e-12));
    });
  });

  group('GradeBranch proportional', () {
    test('ignores subtree with no scores', () {
      final tree = GradeBranch(
        id: 'root',
        name: 'Course',
        children: [
          WeightedChild(
            weight: 50,
            node: GradeLeaf(id: 'a', name: 'A', maxScore: 100, score: 80),
          ),
          WeightedChild(
            weight: 50,
            node: GradeLeaf(id: 'b', name: 'B', maxScore: 100, score: null),
          ),
        ],
      );
      expect(computeNormalizedGrade(tree, CalculationMode.proportional), closeTo(0.8, 1e-12));
    });

    test('no scores anywhere returns null', () {
      final tree = GradeBranch(
        id: 'root',
        name: 'Course',
        children: [
          WeightedChild(
            weight: 1,
            node: GradeLeaf(id: 'a', name: 'A', maxScore: 100, score: null),
          ),
        ],
      );
      expect(computeNormalizedGrade(tree, CalculationMode.proportional), isNull);
    });

    test('nested branch excludes empty branch from denominator', () {
      final tree = GradeBranch(
        id: 'root',
        name: 'Course',
        children: [
          WeightedChild(
            weight: 20,
            node: GradeBranch(
              id: 'labs',
              name: 'Labs',
              children: [
                WeightedChild(
                  weight: 1,
                  node: GradeLeaf(id: 'l1', name: 'L1', maxScore: 100, score: 100),
                ),
              ],
            ),
          ),
          WeightedChild(
            weight: 80,
            node: GradeBranch(
              id: 'exams',
              name: 'Exams',
              children: [
                WeightedChild(
                  weight: 1,
                  node: GradeLeaf(id: 'e1', name: 'E1', maxScore: 100, score: null),
                ),
              ],
            ),
          ),
        ],
      );
      // Only labs subtree contributes: normalized 1.0, weight 20 -> 20/20 = 1.0
      expect(computeNormalizedGrade(tree, CalculationMode.proportional), closeTo(1.0, 1e-12));
    });

    test('empty branch is null', () {
      final tree = GradeBranch(id: 'root', name: 'Empty', children: []);
      expect(computeNormalizedGrade(tree, CalculationMode.proportional), isNull);
    });

    test('equalWeightChildren averages only contributing children', () {
      final tree = GradeBranch(
        id: 'labs',
        name: 'Labs',
        equalWeightChildren: true,
        children: [
          WeightedChild(
            weight: 99,
            node: GradeLeaf(id: 'a', name: 'A', maxScore: 100, score: 100),
          ),
          WeightedChild(
            weight: 1,
            node: GradeLeaf(id: 'b', name: 'B', maxScore: 100, score: null),
          ),
        ],
      );
      expect(computeNormalizedGrade(tree, CalculationMode.proportional), closeTo(1.0, 1e-12));
    });
  });

  group('deep recursion', () {
    test('strict multi-level lab structure', () {
      final tree = GradeBranch(
        id: 'course',
        name: 'Chemistry',
        children: [
          WeightedChild(
            weight: 0.2,
            node: GradeBranch(
              id: 'labs',
              name: 'Labs',
              children: [
                WeightedChild(
                  weight: 0.5,
                  node: GradeLeaf(id: 'r1', name: 'Report', maxScore: 100, score: 90),
                ),
                WeightedChild(
                  weight: 0.5,
                  node: GradeLeaf(id: 'q1', name: 'Quiz', maxScore: 10, score: null),
                ),
              ],
            ),
          ),
          WeightedChild(
            weight: 0.8,
            node: GradeLeaf(id: 'final', name: 'Final', maxScore: 100, score: 70),
          ),
        ],
      );
      // labs: (0.5*0.9 + 0.5*0.0) / 1.0 = 0.45
      // root: (0.2*0.45 + 0.8*0.7) / 1.0 = 0.09 + 0.56 = 0.65
      expect(
        computeNormalizedGrade(tree, CalculationMode.strict),
        closeTo(0.65, 1e-12),
      );
    });
  });
}
