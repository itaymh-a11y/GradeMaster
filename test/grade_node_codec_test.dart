import 'package:flutter_test/flutter_test.dart';
import 'package:grade_master/grade_master.dart';

void main() {
  test('roundtrip empty root', () {
    final n = emptyCourseRootNode();
    final map = gradeNodeToMap(n);
    final back = gradeNodeFromMap(map);
    expect(back, isA<GradeBranch>());
    expect(computeNormalizedGrade(back, CalculationMode.strict), 0.0);
  });

  test('roundtrip nested tree', () {
    final tree = GradeBranch(
      id: 'root',
      name: 'R',
      children: [
        WeightedChild(
          weight: 1,
          node: GradeLeaf(id: 'a', name: 'A', maxScore: 100, score: 75),
        ),
      ],
    );
    final back = gradeNodeFromMap(gradeNodeToMap(tree));
    expect(computeNormalizedGrade(back, CalculationMode.strict), closeTo(0.75, 1e-12));
  });
}
