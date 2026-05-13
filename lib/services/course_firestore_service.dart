import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:grade_master/grade_master.dart';

/// Outcome of [CourseFirestoreService.cloneTemplateToUser].
final class CloneTemplateToUserResult {
  const CloneTemplateToUserResult({
    required this.skippedDuplicate,
    this.courseId,
  });

  /// True when a course with the same [CourseTemplate.id] as [templateId] already exists.
  final bool skippedDuplicate;

  /// New course id, or the existing course id when [skippedDuplicate] is true.
  final String? courseId;
}

/// Firestore access for `users/{uid}/courses/{courseId}`.
class CourseFirestoreService {
  CourseFirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _courses(String uid) {
    return _firestore.collection('users').doc(uid).collection('courses');
  }

  Stream<List<UserCourse>> watchCourses(String uid) {
    return _courses(uid).snapshots().map((snapshot) {
      final list = snapshot.docs.map(_courseFromDoc).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  Future<List<UserCourse>> getCoursesOnce(String uid) async {
    final snapshot = await _courses(uid).get();
    final list = snapshot.docs.map(_courseFromDoc).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Single course document; `null` if missing.
  Stream<UserCourse?> watchCourse(String uid, String courseId) {
    return _courses(uid).doc(courseId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return _courseFromDoc(doc);
    });
  }

  /// Replaces the entire [rootNode] map (after local edits).
  Future<void> updateCourseRoot({
    required String uid,
    required String courseId,
    required GradeNode rootNode,
  }) async {
    await _courses(uid).doc(courseId).update(<String, dynamic>{
      'rootNode': gradeNodeToMap(rootNode),
    });
  }

  /// `null` clears [UserCourse.finalGradeOverride] (FieldValue.delete).
  Future<void> updateCourseFinalGradeOverride({
    required String uid,
    required String courseId,
    double? finalGradeOverride,
  }) async {
    if (finalGradeOverride == null) {
      await _courses(uid).doc(courseId).update(<String, dynamic>{
        'finalGradeOverride': FieldValue.delete(),
      });
    } else {
      await _courses(uid).doc(courseId).update(<String, dynamic>{
        'finalGradeOverride': finalGradeOverride,
      });
    }
  }

  /// Persists a new course; document id is auto-generated. [rootNode] starts empty.
  Future<void> addCourse({
    required String name,
    required double credits,
    required bool isPassFail,
    required AcademicYear academicYear,
    required SemesterKind semester,
    required double finalBonus,
    MoedBPolicy moedBPolicy = MoedBPolicy.higher,
    bool fastGrading = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No signed-in user');
    }
    final doc = _courses(uid).doc();
    final course = UserCourse(
      id: doc.id,
      name: name.trim(),
      credits: credits,
      isPassFail: isPassFail,
      academicYear: academicYear,
      semester: semester,
      finalBonus: finalBonus,
      moedBPolicy: moedBPolicy,
      fastGrading: fastGrading,
      rootNode: fastGrading ? fastGradingRootNode() : emptyCourseRootNode(),
    );
    await doc.set(_courseToMap(course));
  }

  /// Sets [UserCourse.fastGrading]. When turning off, clears [finalGradeOverride] so העץ חוזר להיות מקור האמת.
  Future<void> setCourseFastGradingMode({
    required String uid,
    required String courseId,
    required bool fastGrading,
  }) async {
    if (!fastGrading) {
      await _courses(uid).doc(courseId).update(<String, dynamic>{
        'fastGrading': false,
        'finalGradeOverride': FieldValue.delete(),
      });
    } else {
      await _courses(uid).doc(courseId).update(<String, dynamic>{
        'fastGrading': true,
      });
    }
  }

  /// After onboarding: מוסד וחוג בפרופיל המשתמש.
  Future<void> updateUserInstitutionAndDepartment({
    required String uid,
    required String institutionId,
    required String departmentId,
  }) async {
    await _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'institutionId': institutionId.trim(),
      'departmentId': departmentId.trim(),
    }, SetOptions(merge: true));
  }

  Future<void> updateCourseMeta({
    required String uid,
    required String courseId,
    required String name,
    required double credits,
    required bool isPassFail,
    required AcademicYear academicYear,
    required SemesterKind semester,
    required double finalBonus,
    required MoedBPolicy moedBPolicy,
    required bool fastGrading,
  }) async {
    await _courses(uid).doc(courseId).update(<String, dynamic>{
      'name': name.trim(),
      'credits': credits,
      'isPassFail': isPassFail,
      'academicYear': academicYear.name,
      'semester': semester.name,
      'finalBonus': finalBonus,
      'moedBPolicy': moedBPolicy.name,
      'fastGrading': fastGrading,
    });
  }

  Future<void> deleteCourse(String courseId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No signed-in user');
    }
    await _courses(uid).doc(courseId).delete();
  }

  Future<int> deleteAllCoursesForCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No signed-in user');
    }
    final snap = await _courses(uid).get();
    if (snap.docs.isEmpty) {
      return 0;
    }
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snap.docs.length;
  }

  Map<String, dynamic> _courseToMap(UserCourse course) => courseToFirestoreMap(course);

  UserCourse _courseFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      courseFromFirestoreDoc(doc);

  /// User profile at `users/{uid}` (for [UserModel.isAdmin], onboarding, etc.).
  Stream<UserModel> watchUserModel(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(userModelFromFirestoreDoc);
  }

  /// קריאה חד־פעמית — שימושי לפני אירוע ראשון של ה־stream (למשל כפתור אדמין).
  Future<UserModel> getUserModelOnce(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      return UserModel(uid: uid);
    }
    return userModelFromFirestoreDoc(doc);
  }

  Stream<double?> watchDegreeCreditsTarget(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      final raw = data?['degreeCreditsTarget'];
      if (raw is num) {
        return raw.toDouble();
      }
      return null;
    });
  }

  Stream<double?> watchDegreeGpaTarget(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      final raw = data?['degreeGpaTarget'];
      if (raw is num) {
        return raw.toDouble();
      }
      return null;
    });
  }

  Future<void> updateDegreeCreditsTarget({
    required String uid,
    required double targetCredits,
  }) async {
    await _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'degreeCreditsTarget': targetCredits,
    }, SetOptions(merge: true));
  }

  Future<void> updateDegreeGpaTarget({
    required String uid,
    required double targetGpaPercent,
  }) async {
    await _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'degreeGpaTarget': targetGpaPercent,
    }, SetOptions(merge: true));
  }

  /// Copies [template] into `users/{userId}/courses` as a [UserCourse] with [UserCourse.templateId]
  /// set to the template document id.
  ///
  /// If the user already has any course with that [templateId], returns immediately without writing.
  /// [userId] must match the signed-in user (app-layer guard; enforce in rules as well).
  Future<CloneTemplateToUserResult> cloneTemplateToUser(
    String userId,
    CourseTemplate template,
  ) async {
    final cur = _auth.currentUser?.uid;
    if (cur == null) {
      throw StateError('No signed-in user');
    }
    if (cur != userId) {
      throw StateError('cloneTemplateToUser: userId must match signed-in user');
    }
    final templateKey = template.id;
    final existingSnap = await _courses(userId).get();
    for (final doc in existingSnap.docs) {
      final data = doc.data();
      if (data['templateId'] == templateKey) {
        return CloneTemplateToUserResult(
          skippedDuplicate: true,
          courseId: doc.id,
        );
      }
    }
    final ref = _courses(userId).doc();
    final root = deepCopyGradeNode(template.structureRoot);
    final course = UserCourse(
      id: ref.id,
      name: template.name,
      credits: template.credits,
      rootNode: root,
      isPassFail: template.isPassFail,
      academicYear: template.academicYear,
      semester: template.semester,
      finalBonus: template.finalBonus,
      moedBPolicy: template.moedBPolicy,
      fastGrading: false,
      templateId: templateKey,
    );
    await ref.set(_courseToMap(course));
    return CloneTemplateToUserResult(
      skippedDuplicate: false,
      courseId: ref.id,
    );
  }

  /// כמו [cloneTemplateToUser] אך לכל [targetUid] — מיועד לאדמין מוסד; הכללים מאמתים תבנית מול מוסד/חוג של הסטודנט.
  Future<CloneTemplateToUserResult> cloneTemplateToUserIfMissing({
    required String targetUid,
    required CourseTemplate template,
  }) async {
    final templateKey = template.id;
    final existingSnap = await _courses(targetUid).get();
    for (final doc in existingSnap.docs) {
      final data = doc.data();
      if (data['templateId'] == templateKey) {
        return CloneTemplateToUserResult(
          skippedDuplicate: true,
          courseId: doc.id,
        );
      }
    }
    final ref = _courses(targetUid).doc();
    final root = deepCopyGradeNode(template.structureRoot);
    final course = UserCourse(
      id: ref.id,
      name: template.name,
      credits: template.credits,
      rootNode: root,
      isPassFail: template.isPassFail,
      academicYear: template.academicYear,
      semester: template.semester,
      finalBonus: template.finalBonus,
      moedBPolicy: template.moedBPolicy,
      fastGrading: false,
      templateId: templateKey,
    );
    await ref.set(_courseToMap(course));
    return CloneTemplateToUserResult(
      skippedDuplicate: false,
      courseId: ref.id,
    );
  }
}
