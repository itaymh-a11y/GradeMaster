import 'grade_node.dart';
import 'academic_semester.dart';

/// A single course: metadata and the recursive grade tree ([rootNode]).
final class Course {
  Course({
    required this.id,
    required this.name,
    required this.credits,
    required this.rootNode,
    this.isPassFail = false,
    this.academicYear = AcademicYear.a,
    this.semester = SemesterKind.a,
    this.finalBonus = 0,
    this.moedBPolicy = MoedBPolicy.higher,
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
}
