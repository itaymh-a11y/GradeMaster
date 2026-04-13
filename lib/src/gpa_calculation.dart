import 'calculation_mode.dart';
import 'course.dart';
import 'grade_node.dart';

double? computeCourseNormalizedGrade(Course course, CalculationMode mode) {
  final base = computeNormalizedGrade(
    course.rootNode,
    mode,
    moedBPolicy: course.moedBPolicy,
  );
  if (base == null) {
    return null;
  }
  return base + (course.finalBonus / 100.0);
}

/// Weighted GPA on the **0–1** normalized scale (same as [computeNormalizedGrade] for a course).
///
/// - **Pass/Fail** courses are skipped entirely (they do not affect numerator or denominator).
/// - Courses with **נ״ז 0** are skipped for GPA.
/// - **Proportional:** courses whose tree yields `null` (no data) are skipped.
/// - **Strict:** every non–Pass/Fail course with credits > 0 contributes.
///
/// Returns `null` if there is nothing to average (no contributing courses).
double? computeWeightedGpa(Iterable<Course> courses, CalculationMode mode) {
  var sumCredits = 0.0;
  var sumWeighted = 0.0;

  for (final course in courses) {
    if (course.isPassFail) {
      continue;
    }
    if (course.credits <= 0) {
      continue;
    }

    final normalized = computeCourseNormalizedGrade(course, mode);
    if (normalized == null) {
      continue;
    }

    sumWeighted += course.credits * normalized;
    sumCredits += course.credits;
  }

  if (sumCredits == 0.0) {
    return null;
  }

  return sumWeighted / sumCredits;
}

/// Cumulative GPA over an arbitrary list (e.g. entire degree to date).
double? computeCumulativeGpa(Iterable<Course> courses, CalculationMode mode) {
  return computeWeightedGpa(courses, mode);
}

/// Portion of course grade already "closed" in strict mode (0..1).
///
/// Leaf with score contributes 1, missing contributes 0.
/// Branch aggregation follows the same local weighting logic as strict grade
/// (including equal-weight branches).
double computeStrictClosedPortion(GradeNode node) {
  switch (node) {
    case GradeLeaf(:final score, :final isMoedBActive, :final moedBScore):
      final hasSelected = isMoedBActive && moedBScore != null
          ? true
          : score != null;
      return hasSelected ? 1.0 : 0.0;
    case GradeBranch(:final children, :final equalWeightChildren):
      if (children.isEmpty) {
        return 0.0;
      }
      if (equalWeightChildren) {
        final each = 1.0 / children.length;
        var sum = 0.0;
        for (final wc in children) {
          sum += each * computeStrictClosedPortion(wc.node);
        }
        return sum;
      }
      var sumW = 0.0;
      var sum = 0.0;
      for (final wc in children) {
        sumW += wc.weight;
        sum += wc.weight * computeStrictClosedPortion(wc.node);
      }
      if (sumW == 0.0) {
        return 0.0;
      }
      return sum / sumW;
  }
}
