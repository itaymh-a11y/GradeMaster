import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:grade_master/grade_master.dart';

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

  Stream<List<Course>> watchCourses(String uid) {
    return _courses(uid).orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map(_courseFromDoc).toList();
    });
  }

  /// Single course document; `null` if missing.
  Stream<Course?> watchCourse(String uid, String courseId) {
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

  /// Persists a new course; document id is auto-generated. [rootNode] starts empty.
  Future<void> addCourse({
    required String name,
    required double credits,
    required bool isPassFail,
    required AcademicYear academicYear,
    required SemesterKind semester,
    required double finalBonus,
    MoedBPolicy moedBPolicy = MoedBPolicy.higher,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No signed-in user');
    }
    final doc = _courses(uid).doc();
    final course = Course(
      id: doc.id,
      name: name.trim(),
      credits: credits,
      isPassFail: isPassFail,
      academicYear: academicYear,
      semester: semester,
      finalBonus: finalBonus,
      moedBPolicy: moedBPolicy,
      rootNode: emptyCourseRootNode(),
    );
    await doc.set(_courseToMap(course));
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
  }) async {
    await _courses(uid).doc(courseId).update(<String, dynamic>{
      'name': name.trim(),
      'credits': credits,
      'isPassFail': isPassFail,
      'academicYear': academicYear.name,
      'semester': semester.name,
      'finalBonus': finalBonus,
      'moedBPolicy': moedBPolicy.name,
    });
  }

  Future<void> deleteCourse(String courseId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No signed-in user');
    }
    await _courses(uid).doc(courseId).delete();
  }

  Map<String, dynamic> _courseToMap(Course course) {
    return <String, dynamic>{
      'name': course.name,
      'credits': course.credits,
      'isPassFail': course.isPassFail,
      'academicYear': course.academicYear.name,
      'semester': course.semester.name,
      'finalBonus': course.finalBonus,
      'moedBPolicy': course.moedBPolicy.name,
      'rootNode': gradeNodeToMap(course.rootNode),
    };
  }

  Course _courseFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Course ${doc.id} has no data');
    }
    final rootRaw = data['rootNode'];
    if (rootRaw is! Map) {
      throw FormatException('Course ${doc.id}: rootNode missing or invalid');
    }
    return Course(
      id: doc.id,
      name: data['name'] as String,
      credits: (data['credits'] as num).toDouble(),
      isPassFail: data['isPassFail'] as bool? ?? false,
      academicYear: _yearFromRaw(data['academicYear']),
      semester: _semesterFromRaw(data['semester']),
      finalBonus: (data['finalBonus'] as num?)?.toDouble() ?? 0,
      moedBPolicy: _moedBPolicyFromRaw(data['moedBPolicy']),
      rootNode: gradeNodeFromMap(Map<String, dynamic>.from(rootRaw)),
    );
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
}
