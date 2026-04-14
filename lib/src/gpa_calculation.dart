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

/// Weighted degree average on the **0–1** normalized scale.
///
/// Rules:
/// - Pass/Fail courses are skipped.
/// - Courses with credits <= 0 are skipped.
/// - Only courses with 100% closed components are included.
/// - Course grade is always calculated proportionally.
///
/// Returns `null` when no course can contribute.
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

    if (computeStrictClosedPortion(course.rootNode) < 0.999999) {
      continue;
    }

    final normalized = computeCourseNormalizedGrade(
      course,
      CalculationMode.proportional,
    );
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
