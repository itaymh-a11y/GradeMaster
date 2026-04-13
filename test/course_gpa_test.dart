import 'package:flutter_test/flutter_test.dart';
import 'package:grade_master/grade_master.dart';

GradeNode _leaf(String id, double max, double? score) =>
    GradeLeaf(id: id, name: id, maxScore: max, score: score);

Course _course({
  required String id,
  required double credits,
  required GradeNode root,
  bool passFail = false,
}) {
  return Course(
    id: id,
    name: 'Course $id',
    credits: credits,
    rootNode: root,
    isPassFail: passFail,
  );
}

void main() {
  group('computeWeightedGpa', () {
    test('two courses weighted by credits', () {
      final courses = [
        _course(
          id: 'a',
          credits: 3,
          root: _leaf('g', 100, 80),
        ),
        _course(
          id: 'b',
          credits: 4,
          root: _leaf('g', 100, 60),
        ),
      ];
      expect(
        computeWeightedGpa(courses, CalculationMode.strict),
        closeTo((3 * 0.8 + 4 * 0.6) / 7, 1e-12),
      );
    });

    test('Pass/Fail excluded from GPA but list can include it', () {
      final courses = [
        _course(id: 'graded', credits: 5, root: _leaf('g', 100, 100)),
        _course(
          id: 'pf',
          credits: 2,
          root: _leaf('g', 100, 50),
          passFail: true,
        ),
      ];
      expect(computeWeightedGpa(courses, CalculationMode.strict), closeTo(1.0, 1e-12));
    });

    test('proportional skips course with no grades in tree', () {
      final courses = [
        _course(id: 'a', credits: 3, root: _leaf('g', 100, 90)),
        _course(
          id: 'b',
          credits: 5,
          root: _leaf('g', 100, null),
        ),
      ];
      expect(
        computeWeightedGpa(courses, CalculationMode.proportional),
        closeTo(0.9, 1e-12),
      );
    });

    test('proportional returns null when only Pass/Fail or empty', () {
      expect(
        computeWeightedGpa(
          [
            _course(
              id: 'pf',
              credits: 3,
              root: _leaf('g', 100, 100),
              passFail: true,
            ),
          ],
          CalculationMode.proportional,
        ),
        isNull,
      );
      expect(
        computeWeightedGpa(
          [_course(id: 'x', credits: 2, root: _leaf('g', 100, null))],
          CalculationMode.proportional,
        ),
        isNull,
      );
    });

    test('zero credits course skipped for GPA', () {
      final courses = [
        _course(id: 'a', credits: 0, root: _leaf('g', 100, 100)),
        _course(id: 'b', credits: 4, root: _leaf('g', 100, 50)),
      ];
      expect(computeWeightedGpa(courses, CalculationMode.strict), closeTo(0.5, 1e-12));
    });

    test('course final bonus is included in weighted GPA', () {
      final courses = [
        Course(
          id: 'a',
          name: 'A',
          credits: 3,
          rootNode: _leaf('g', 100, 80),
          finalBonus: 2,
        ),
      ];
      expect(computeWeightedGpa(courses, CalculationMode.strict), closeTo(0.82, 1e-12));
    });
  });

  group('computeCumulativeGpa', () {
    test('same as weighted over full list', () {
      final courses = [
        _course(id: 'x', credits: 1, root: _leaf('g', 100, 70)),
      ];
      expect(
        computeCumulativeGpa(courses, CalculationMode.strict),
        computeWeightedGpa(courses, CalculationMode.strict),
      );
    });
  });
}
