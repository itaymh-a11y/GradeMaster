import 'package:cloud_firestore/cloud_firestore.dart';

import 'academic_semester.dart';
import 'course.dart';
import 'course_template.dart';
import 'grade_node.dart';
import 'user_model.dart';
import 'grade_node_codec.dart';

DateTime? _dateTimeFromRaw(Object? raw) {
  if (raw is Timestamp) {
    return raw.toDate();
  }
  return null;
}

AcademicYear _yearFromRaw(Object? raw) {
  return switch (raw) {
    'b' => AcademicYear.b,
    'c' => AcademicYear.c,
    'd' => AcademicYear.d,
    _ => AcademicYear.a,
  };
}

SemesterKind _semesterFromRaw(Object? raw) {
  return switch (raw) {
    'b' => SemesterKind.b,
    'summer' => SemesterKind.summer,
    _ => SemesterKind.a,
  };
}

MoedBPolicy _moedBPolicyFromRaw(Object? raw) {
  return switch (raw) {
    'moedB' => MoedBPolicy.moedB,
    _ => MoedBPolicy.higher,
  };
}

AcademicYear? _optionalYearFromRaw(Object? raw) {
  if (raw == null) {
    return null;
  }
  return switch (raw) {
    String s when s.isNotEmpty => _yearFromRaw(s),
    _ => null,
  };
}

/// Map saved on `users/{uid}/courses/{courseId}`.
Map<String, dynamic> courseToFirestoreMap(UserCourse course) {
  return <String, dynamic>{
    'name': course.name,
    'credits': course.credits,
    'isPassFail': course.isPassFail,
    'academicYear': course.academicYear.name,
    'semester': course.semester.name,
    'finalBonus': course.finalBonus,
    'moedBPolicy': course.moedBPolicy.name,
    'fastGrading': course.fastGrading,
    'rootNode': gradeNodeToMap(course.rootNode),
    if (course.templateId != null) 'templateId': course.templateId,
    if (course.finalGradeOverride != null)
      'finalGradeOverride': course.finalGradeOverride,
  };
}

UserCourse courseFromFirestoreDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  if (data == null) {
    throw StateError('Course ${doc.id} has no data');
  }
  return courseFromFirestoreMap(Map<String, dynamic>.from(data), id: doc.id);
}

UserCourse courseFromFirestoreMap(Map<String, dynamic> data, {required String id}) {
  final rootRaw = data['rootNode'];
  if (rootRaw is! Map) {
    throw FormatException('Course $id: rootNode missing or invalid');
  }
  final rawOverride = data['finalGradeOverride'];
  return UserCourse(
    id: id,
    name: data['name'] as String,
    credits: (data['credits'] as num).toDouble(),
    isPassFail: data['isPassFail'] as bool? ?? false,
    academicYear: _yearFromRaw(data['academicYear']),
    semester: _semesterFromRaw(data['semester']),
    finalBonus: (data['finalBonus'] as num?)?.toDouble() ?? 0,
    moedBPolicy: _moedBPolicyFromRaw(data['moedBPolicy']),
    fastGrading: data['fastGrading'] as bool? ?? false,
    rootNode: gradeNodeFromMap(Map<String, dynamic>.from(rootRaw)),
    templateId: data['templateId'] as String?,
    finalGradeOverride: rawOverride == null ? null : (rawOverride as num).toDouble(),
  );
}

/// Document body inside `course_templates`; `lastUpdated` is server-driven in practice.
Map<String, dynamic> courseTemplateToFirestoreMap(CourseTemplate t) {
  return <String, dynamic>{
    'templateId': t.templateId,
    'version': t.version,
    'name': t.name,
    'credits': t.credits,
    'isPassFail': t.isPassFail,
    'academicYear': t.academicYear.name,
    'semester': t.semester.name,
    'finalBonus': t.finalBonus,
    'moedBPolicy': t.moedBPolicy.name,
    'fastGrading': false,
    'rootNode': gradeNodeToMap(t.structureRoot),
    if (t.lastUpdated != null) 'lastUpdated': Timestamp.fromDate(t.lastUpdated!),
  };
}

CourseTemplate courseTemplateFromFirestoreDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data();
  if (data == null) {
    throw StateError('CourseTemplate ${doc.id} has no data');
  }
  return courseTemplateFromFirestoreMap(Map<String, dynamic>.from(data), id: doc.id);
}

CourseTemplate courseTemplateFromFirestoreMap(
  Map<String, dynamic> data, {
  required String id,
}) {
  final rootRaw = data['rootNode'];
  if (rootRaw is! Map) {
    throw FormatException('CourseTemplate $id: rootNode missing or invalid');
  }
  final templateIdRaw = data['templateId'] as String?;
  return CourseTemplate(
    id: id,
    templateId: templateIdRaw ?? id,
    name: data['name'] as String,
    credits: (data['credits'] as num).toDouble(),
    isPassFail: data['isPassFail'] as bool? ?? false,
    academicYear: _yearFromRaw(data['academicYear']),
    semester: _semesterFromRaw(data['semester']),
    finalBonus: (data['finalBonus'] as num?)?.toDouble() ?? 0,
    moedBPolicy: _moedBPolicyFromRaw(data['moedBPolicy']),
    // Institutional templates are always full-structure (no fast-grading mode).
    fastGrading: false,
    structureRoot: gradeNodeFromMap(Map<String, dynamic>.from(rootRaw)),
    version: (data['version'] as num?)?.toInt() ?? 1,
    lastUpdated: _dateTimeFromRaw(data['lastUpdated']),
  );
}

Map<String, dynamic> userModelToFirestoreMap(UserModel model) {
  return <String, dynamic>{
    if (model.email != null) 'email': model.email,
    if (model.institutionId != null) 'institutionId': model.institutionId,
    if (model.departmentId != null) 'departmentId': model.departmentId,
    if (model.studentAcademicYear != null)
      'studentAcademicYear': model.studentAcademicYear!.name,
    if (model.degreeCreditsTarget != null)
      'degreeCreditsTarget': model.degreeCreditsTarget,
    if (model.degreeGpaTarget != null) 'degreeGpaTarget': model.degreeGpaTarget,
    'isAdmin': model.isAdmin,
  };
}

UserModel userModelFromFirestoreDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  if (data == null) {
    return UserModel(uid: doc.id);
  }
  return UserModel(
    uid: doc.id,
    email: data['email'] as String?,
    createdAt: _dateTimeFromRaw(data['createdAt']),
    institutionId: data['institutionId'] as String?,
    departmentId: data['departmentId'] as String?,
    studentAcademicYear: _optionalYearFromRaw(data['studentAcademicYear']),
    degreeCreditsTarget: (data['degreeCreditsTarget'] as num?)?.toDouble(),
    degreeGpaTarget: (data['degreeGpaTarget'] as num?)?.toDouble(),
    isAdmin: data['isAdmin'] as bool? ?? false,
  );
}
