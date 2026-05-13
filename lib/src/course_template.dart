import 'academic_semester.dart';
import 'grade_node.dart';

/// Canonical template row under
/// `institutions/{institutionId}/departments/{departmentId}/course_templates/{id}`.
///
/// Uses [GradeNode] for the grading structure; leaf [GradeLeaf.score] values must stay
/// `null` until the doc is cloned into a user-owned course ([Course]).
///
/// [academicYear] and [semester] are the **degree slot** for this template (e.g. שנה א׳ סמסטר ב׳).
/// They are taken from the admin’s [UserCourse] when saving via cloud upload, and copied onto
/// the student’s [UserCourse] when [CourseFirestoreService.cloneTemplateToUser] runs.
final class CourseTemplate {
  CourseTemplate({
    required this.id,
    required this.templateId,
    required this.name,
    required this.credits,
    required this.structureRoot,
    required this.fastGrading,
    this.version = 1,
    this.lastUpdated,
    this.isPassFail = false,
    this.academicYear = AcademicYear.a,
    this.semester = SemesterKind.a,
    this.finalBonus = 0,
    this.moedBPolicy = MoedBPolicy.higher,
  }) : assert(credits >= 0);

  /// Firestore document id for this template row (path segment after `course_templates`).
  final String id;

  /// Stored field for portable exports / merges; mirrors [id] when written from tooling.
  final String templateId;

  final String name;
  final double credits;
  final GradeNode structureRoot;
  final bool isPassFail;
  final AcademicYear academicYear;
  final SemesterKind semester;
  final double finalBonus;
  final MoedBPolicy moedBPolicy;
  final bool fastGrading;

  /// Basic versioning for admin edits (separate from [DegreeTemplate.version] meta-docs).
  final int version;

  final DateTime? lastUpdated;

  CourseTemplate copyWith({
    String? id,
    String? templateId,
    String? name,
    double? credits,
    GradeNode? structureRoot,
    bool? isPassFail,
    AcademicYear? academicYear,
    SemesterKind? semester,
    double? finalBonus,
    MoedBPolicy? moedBPolicy,
    bool? fastGrading,
    int? version,
    DateTime? lastUpdated,
  }) {
    return CourseTemplate(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      credits: credits ?? this.credits,
      structureRoot: structureRoot ?? this.structureRoot,
      isPassFail: isPassFail ?? this.isPassFail,
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      finalBonus: finalBonus ?? this.finalBonus,
      moedBPolicy: moedBPolicy ?? this.moedBPolicy,
      fastGrading: fastGrading ?? this.fastGrading,
      version: version ?? this.version,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
