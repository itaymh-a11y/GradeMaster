import 'grade_node.dart';
import 'academic_semester.dart';

/// User-owned course instance (possibly cloned from a [CourseTemplate]).
///
/// Also exposed as [Course] for legacy imports across the app.
final class UserCourse {
  UserCourse({
    required this.id,
    required this.name,
    required this.credits,
    required this.rootNode,
    this.isPassFail = false,
    this.academicYear = AcademicYear.a,
    this.semester = SemesterKind.a,
    this.finalBonus = 0,
    this.moedBPolicy = MoedBPolicy.higher,
    this.fastGrading = false,
    /// Id of the `course_templates` doc this row was cloned from, if any.
    this.templateId,
    /// When set, UI may treat the course as "final grade only" (שלב 5).
    this.finalGradeOverride,
  }) : assert(credits >= 0, 'credits must be non-negative');

  final String id;
  final String name;

  /// נקודות זכות (נ״ז). Pass/Fail: shown in lists; GPA weight 0.
  final double credits;

  /// Root of the recursive grade structure for this course.
  final GradeNode rootNode;

  /// When true, excluded from GPA aggregation (still listed).
  final bool isPassFail;

  final AcademicYear academicYear;
  final SemesterKind semester;
  final double finalBonus;
  final MoedBPolicy moedBPolicy;
  final bool fastGrading;

  final String? templateId;
  final double? finalGradeOverride;
}

/// Backward-compatible alias for [UserCourse].
typedef Course = UserCourse;
