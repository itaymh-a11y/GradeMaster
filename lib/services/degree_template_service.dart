import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:grade_master/grade_master.dart';

final class DegreeTemplateApplyResult {
  const DegreeTemplateApplyResult({
    required this.importedCoursesCount,
    required this.deletedCoursesCount,
  });

  final int importedCoursesCount;
  final int deletedCoursesCount;
}

/// Firestore access for shared degree templates and snapshot import into users.
class DegreeTemplateService {
  DegreeTemplateService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _templates =>
      _firestore.collection('degreeTemplates');

  CollectionReference<Map<String, dynamic>> _templateCourses(String templateId) {
    return _templates.doc(templateId).collection('courses');
  }

  CollectionReference<Map<String, dynamic>> _userCourses(String uid) {
    return _firestore.collection('users').doc(uid).collection('courses');
  }

  Stream<List<DegreeTemplate>> watchPublishedTemplates() {
    return _templates
        .where('status', isEqualTo: DegreeTemplateStatus.published.name)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map(_templateFromDoc).toList()
            ..sort((a, b) {
              final byDegree = a.degreeName.compareTo(b.degreeName);
              if (byDegree != 0) {
                return byDegree;
              }
              return a.institutionName.compareTo(b.institutionName);
            });
          return list;
        });
  }

  Stream<List<DegreeTemplate>> watchAllTemplatesForAdmin() {
    return _templates.orderBy('updatedAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map(_templateFromDoc).toList();
    });
  }

  Stream<List<UserCourse>> watchTemplateCourses(String templateId) {
    return _templateCourses(templateId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(_courseFromDoc).toList();
        });
  }

  Future<String> createTemplate({
    required String degreeName,
    required String institutionName,
    required String cohortLabel,
    required double degreeCreditsTarget,
    DegreeTemplateStatus status = DegreeTemplateStatus.draft,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }
    final doc = _templates.doc();
    await doc.set(<String, dynamic>{
      'degreeName': degreeName.trim(),
      'institutionName': institutionName.trim(),
      'cohortLabel': cohortLabel.trim(),
      'degreeCreditsTarget': degreeCreditsTarget,
      'status': status.name,
      'version': 1,
      'createdByUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateTemplateMeta({
    required String templateId,
    required String degreeName,
    required String institutionName,
    required String cohortLabel,
    required double degreeCreditsTarget,
    required DegreeTemplateStatus status,
    bool bumpVersion = true,
  }) async {
    final updates = <String, dynamic>{
      'degreeName': degreeName.trim(),
      'institutionName': institutionName.trim(),
      'cohortLabel': cohortLabel.trim(),
      'degreeCreditsTarget': degreeCreditsTarget,
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (bumpVersion) {
      updates['version'] = FieldValue.increment(1);
    }
    await _templates.doc(templateId).update(updates);
  }

  Future<void> replaceTemplateCourses({
    required String templateId,
    required List<UserCourse> courses,
    bool bumpVersion = true,
  }) async {
    final existing = await _templateCourses(templateId).get();
    final batch = _firestore.batch();

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final course in courses) {
      final ref = _templateCourses(templateId).doc();
      final copy = UserCourse(
        id: ref.id,
        name: course.name,
        credits: course.credits,
        rootNode: course.rootNode,
        isPassFail: course.isPassFail,
        academicYear: course.academicYear,
        semester: course.semester,
        finalBonus: course.finalBonus,
        moedBPolicy: course.moedBPolicy,
        fastGrading: course.fastGrading,
        templateId: ref.id,
      );
      batch.set(ref, _courseToMap(copy));
    }

    final templateRef = _templates.doc(templateId);
    batch.update(templateRef, <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      if (bumpVersion) 'version': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> addTemplateCourse({
    required String templateId,
    required String name,
    required double credits,
    required bool fastGrading,
  }) async {
    final ref = _templateCourses(templateId).doc();
    final course = UserCourse(
      id: ref.id,
      name: name.trim(),
      credits: credits,
      isPassFail: false,
      academicYear: AcademicYear.a,
      semester: SemesterKind.a,
      finalBonus: 0,
      moedBPolicy: MoedBPolicy.higher,
      fastGrading: fastGrading,
      rootNode: fastGrading ? fastGradingRootNode() : emptyCourseRootNode(),
      templateId: ref.id,
    );
    final batch = _firestore.batch();
    batch.set(ref, _courseToMap(course));
    batch.update(_templates.doc(templateId), <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'version': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> deleteTemplateCourse({
    required String templateId,
    required String courseId,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_templateCourses(templateId).doc(courseId));
    batch.update(_templates.doc(templateId), <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'version': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> deleteTemplate(String templateId) async {
    final courses = await _templateCourses(templateId).get();
    final batch = _firestore.batch();
    for (final doc in courses.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_templates.doc(templateId));
    await batch.commit();
  }

  Future<DegreeTemplateApplyResult> applyTemplateToCurrentUser({
    required String templateId,
    required TemplateImportMode mode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }
    final templateRef = _templates.doc(templateId);
    final templateSnap = await templateRef.get();
    if (!templateSnap.exists) {
      throw StateError('Template not found: $templateId');
    }
    final template = _templateFromDoc(templateSnap);
    final templateCourses = await _templateCourses(templateId).get();
    final userCourses = await _userCourses(user.uid).get();

    final batch = _firestore.batch();
    var deletedCoursesCount = 0;

    if (mode == TemplateImportMode.replace) {
      for (final doc in userCourses.docs) {
        batch.delete(doc.reference);
      }
      deletedCoursesCount = userCourses.docs.length;
    }

    for (final templateCourseDoc in templateCourses.docs) {
      final parsedCourse = _courseFromDoc(templateCourseDoc);
      final userCourseRef = _userCourses(user.uid).doc();
      final userCourse = UserCourse(
        id: userCourseRef.id,
        name: parsedCourse.name,
        credits: parsedCourse.credits,
        rootNode: parsedCourse.rootNode,
        isPassFail: parsedCourse.isPassFail,
        academicYear: parsedCourse.academicYear,
        semester: parsedCourse.semester,
        finalBonus: parsedCourse.finalBonus,
        moedBPolicy: parsedCourse.moedBPolicy,
        fastGrading: parsedCourse.fastGrading,
        templateId: parsedCourse.templateId ?? templateCourseDoc.id,
      );
      batch.set(userCourseRef, _courseToMap(userCourse));
    }

    final userDocRef = _firestore.collection('users').doc(user.uid);
    batch.set(userDocRef, <String, dynamic>{
      'degreeCreditsTarget': template.degreeCreditsTarget,
      'appliedTemplate': <String, dynamic>{
        'templateId': template.id,
        'templateDisplayName': template.displayName,
        'templateVersion': template.version,
        'mode': mode.name,
        'appliedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));

    await batch.commit();
    return DegreeTemplateApplyResult(
      importedCoursesCount: templateCourses.docs.length,
      deletedCoursesCount: deletedCoursesCount,
    );
  }

  Map<String, dynamic> _courseToMap(UserCourse course) => courseToFirestoreMap(course);

  UserCourse _courseFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      courseFromFirestoreDoc(doc);

  DegreeTemplate _templateFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Template ${doc.id} has no data');
    }
    return DegreeTemplate(
      id: doc.id,
      degreeName: (data['degreeName'] as String? ?? '').trim(),
      institutionName: (data['institutionName'] as String? ?? '').trim(),
      cohortLabel: (data['cohortLabel'] as String? ?? '').trim(),
      degreeCreditsTarget: (data['degreeCreditsTarget'] as num?)?.toDouble() ?? 0,
      status: _templateStatusFromRaw(data['status']),
      version: (data['version'] as num?)?.toInt() ?? 1,
      createdByUid: (data['createdByUid'] as String? ?? '').trim(),
      createdAt: _dateTimeFromRaw(data['createdAt']),
      updatedAt: _dateTimeFromRaw(data['updatedAt']),
    );
  }

  DateTime? _dateTimeFromRaw(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    return null;
  }

  DegreeTemplateStatus _templateStatusFromRaw(Object? raw) {
    return switch (raw) {
      'published' => DegreeTemplateStatus.published,
      'archived' => DegreeTemplateStatus.archived,
      _ => DegreeTemplateStatus.draft,
    };
  }

}
