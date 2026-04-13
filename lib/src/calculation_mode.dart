/// User-selectable aggregation behavior for missing grades.
enum CalculationMode {
  /// Missing scores count as 0; all defined weights participate in the denominator.
  strict,

  /// Only children with a defined normalized grade participate; denominator is the sum
  /// of their weights. If nothing contributes, [computeNormalizedGrade] returns `null`.
  proportional,
}
