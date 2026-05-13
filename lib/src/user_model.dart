import 'academic_semester.dart';

/// User profile persisted at `users/{uid}` alongside auth bootstrap fields.
final class UserModel {
  UserModel({
    required this.uid,
    this.email,
    this.createdAt,
    this.institutionId,
    this.departmentId,
    /// מסגרת שנת ההתחלה בסט שנוכחית (שנת א׳–ד׳), לפונקציות אונבורדינג.
    this.studentAcademicYear,
    this.degreeCreditsTarget,
    this.degreeGpaTarget,
    this.isAdmin = false,
  });

  final String uid;
  final String? email;
  final DateTime? createdAt;

  /// `institutions` collection doc id.
  final String? institutionId;

  /// Parent doc id under `institutions/{id}/departments`.
  final String? departmentId;

  final AcademicYear? studentAcademicYear;

  final double? degreeCreditsTarget;
  final double? degreeGpaTarget;

  /// When true, user may manage public templates (see [AdminService]); enforce in Security Rules too.
  final bool isAdmin;

  /// True until both [institutionId] and [departmentId] are set (onboarding / בחירת תואר).
  bool get needsInstitutionOnboarding {
    final i = institutionId?.trim() ?? '';
    final d = departmentId?.trim() ?? '';
    return i.isEmpty || d.isEmpty;
  }

  UserModel copyWith({
    String? uid,
    String? email,
    DateTime? createdAt,
    String? institutionId,
    String? departmentId,
    AcademicYear? studentAcademicYear,
    double? degreeCreditsTarget,
    double? degreeGpaTarget,
    bool? isAdmin,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      institutionId: institutionId ?? this.institutionId,
      departmentId: departmentId ?? this.departmentId,
      studentAcademicYear: studentAcademicYear ?? this.studentAcademicYear,
      degreeCreditsTarget: degreeCreditsTarget ?? this.degreeCreditsTarget,
      degreeGpaTarget: degreeGpaTarget ?? this.degreeGpaTarget,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
