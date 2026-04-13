import 'package:flutter_test/flutter_test.dart';
import 'package:grade_master/grade_master.dart';

void main() {
  test('addChildToBranch appends to target branch', () {
    final root = GradeBranch(
      id: 'root',
      name: 'R',
      children: [
        WeightedChild(
          weight: 1,
          node: GradeBranch(id: 'b', name: 'Labs', children: []),
        ),
      ],
    );
    final leaf = GradeLeaf(id: 'l', name: 'L1', maxScore: 10, score: 8);
    final next = addChildToBranch(
      root,
      'b',
      WeightedChild(weight: 2, node: leaf),
    );
    final b = (next as GradeBranch).children.first.node as GradeBranch;
    expect(b.children.length, 1);
    expect(b.children.first.weight, 2);
  });

  test('removeNodeById removes subtree', () {
    final root = GradeBranch(
      id: 'root',
      name: 'R',
      children: [
        WeightedChild(
          weight: 1,
          node: GradeBranch(
            id: 'labs',
            name: 'Labs',
            children: [
              WeightedChild(
                weight: 1,
                node: GradeLeaf(id: 'l', name: 'L1', maxScore: 10, score: 5),
              ),
            ],
          ),
        ),
      ],
    );
    final next = removeNodeById(root, 'labs');
    expect((next as GradeBranch).children, isEmpty);
  });

  test('removeNodeById throws on root', () {
    final root = GradeBranch(id: 'root', name: 'R', children: []);
    expect(() => removeNodeById(root, 'root'), throwsArgumentError);
  });

  test('updateNodeName and updateEdgeWeight', () {
    final root = GradeBranch(
      id: 'root',
      name: 'R',
      children: [
        WeightedChild(
          weight: 25,
          node: GradeLeaf(id: 'x', name: 'A', maxScore: 100, score: 50),
        ),
      ],
    );
    var r = updateNodeName(root, 'x', 'מבחן סופי');
    r = updateEdgeWeight(r, 'x', 85);
    final branch = r as GradeBranch;
    expect(branch.children.first.weight, 85);
    final leaf = branch.children.first.node as GradeLeaf;
    expect(leaf.name, 'מבחן סופי');
  });

  test('replaceNodeById updates leaf', () {
    final root = GradeBranch(
      id: 'root',
      name: 'R',
      children: [
        WeightedChild(
          weight: 1,
          node: GradeLeaf(id: 'x', name: 'A', maxScore: 100, score: 50),
        ),
      ],
    );
    final next = replaceNodeById(
      root,
      'x',
      GradeLeaf(id: 'x', name: 'A', maxScore: 100, score: 90),
    );
    final leaf = (next as GradeBranch).children.first.node as GradeLeaf;
    expect(leaf.score, 90);
  });
}
