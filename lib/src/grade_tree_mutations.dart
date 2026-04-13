import 'grade_node.dart';

/// Immutable updates to a [GradeNode] tree (by node [id]).

GradeNode replaceNodeById(GradeNode root, String nodeId, GradeNode newNode) {
  if (root.id == nodeId) {
    return newNode;
  }
  switch (root) {
    case GradeLeaf():
      return root;
    case GradeBranch(
      :final id,
      :final name,
      :final children,
      :final equalWeightChildren,
    ):
      return GradeBranch(
        id: id,
        name: name,
        equalWeightChildren: equalWeightChildren,
        children: children
            .map(
              (wc) => WeightedChild(
                weight: wc.weight,
                node: replaceNodeById(wc.node, nodeId, newNode),
              ),
            )
            .toList(),
      );
  }
}

/// Appends [newChild] to the [WeightedChild] list of the branch whose id is [branchId].
GradeNode addChildToBranch(
  GradeNode root,
  String branchId,
  WeightedChild newChild,
) {
  switch (root) {
    case GradeBranch(
      :final id,
      :final name,
      :final children,
      :final equalWeightChildren,
    )
        when id == branchId:
      return GradeBranch(
        id: id,
        name: name,
        equalWeightChildren: equalWeightChildren,
        children: [...children, newChild],
      );
    case GradeLeaf():
      return root;
    case GradeBranch(
      :final id,
      :final name,
      :final children,
      :final equalWeightChildren,
    ):
      return GradeBranch(
        id: id,
        name: name,
        equalWeightChildren: equalWeightChildren,
        children: children
            .map(
              (wc) => WeightedChild(
                weight: wc.weight,
                node: addChildToBranch(wc.node, branchId, newChild),
              ),
            )
            .toList(),
      );
  }
}

/// Removes the subtree whose root id is [nodeId]. Cannot remove the tree root (`root`).
GradeNode removeNodeById(GradeNode root, String nodeId) {
  if (root.id == nodeId) {
    throw ArgumentError('Cannot remove root node');
  }
  return _removeNodeRecursive(root, nodeId);
}

GradeNode _removeNodeRecursive(GradeNode node, String targetId) {
  switch (node) {
    case GradeLeaf():
      return node;
    case GradeBranch(
      :final id,
      :final name,
      :final children,
      :final equalWeightChildren,
    ):
      final newChildren = <WeightedChild>[];
      for (final wc in children) {
        if (wc.node.id == targetId) {
          continue;
        }
        newChildren.add(
          WeightedChild(
            weight: wc.weight,
            node: _removeNodeRecursive(wc.node, targetId),
          ),
        );
      }
      return GradeBranch(
        id: id,
        name: name,
        equalWeightChildren: equalWeightChildren,
        children: newChildren,
      );
  }
}

/// Renames a node by [nodeId].
GradeNode updateNodeName(GradeNode root, String nodeId, String newName) {
  final trimmed = newName.trim();
  if (root.id == nodeId) {
    return switch (root) {
      GradeLeaf(:final id, :final maxScore, :final score) => GradeLeaf(
          id: id,
          name: trimmed,
          maxScore: maxScore,
          score: score,
        ),
      GradeBranch(
        :final id,
        :final children,
        :final equalWeightChildren,
      ) =>
        GradeBranch(
          id: id,
          name: trimmed,
          equalWeightChildren: equalWeightChildren,
          children: children,
        ),
    };
  }
  switch (root) {
    case GradeLeaf():
      return root;
    case GradeBranch(
      :final id,
      :final name,
      :final children,
      :final equalWeightChildren,
    ):
      return GradeBranch(
        id: id,
        name: name,
        equalWeightChildren: equalWeightChildren,
        children: children
            .map(
              (wc) => WeightedChild(
                weight: wc.weight,
                node: updateNodeName(wc.node, nodeId, trimmed),
              ),
            )
            .toList(),
      );
  }
}

/// Updates the incoming edge weight to [nodeId] (not valid for root).
GradeNode updateEdgeWeight(GradeNode root, String nodeId, double newWeight) {
  if (root.id == nodeId) {
    throw ArgumentError('Root has no incoming weight');
  }
  switch (root) {
    case GradeLeaf():
      return root;
    case GradeBranch(
      :final id,
      :final name,
      :final children,
      :final equalWeightChildren,
    ):
      return GradeBranch(
        id: id,
        name: name,
        equalWeightChildren: equalWeightChildren,
        children: children.map((wc) {
          if (wc.node.id == nodeId) {
            return WeightedChild(weight: newWeight, node: wc.node);
          }
          return WeightedChild(
            weight: wc.weight,
            node: updateEdgeWeight(wc.node, nodeId, newWeight),
          );
        }).toList(),
      );
  }
}
