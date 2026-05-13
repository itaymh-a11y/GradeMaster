import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:grade_master/grade_master.dart';

import 'auth_service.dart';
import 'course_firestore_service.dart';

final class ReadyDepartmentOption {
  const ReadyDepartmentOption({
    required this.institutionId,
    required this.institutionLabel,
    required this.departmentId,
    required this.departmentLabel,
  });

  final String institutionId;
  final String institutionLabel;
  final String departmentId;
  final String departmentLabel;

  String get displayName => '$institutionLabel - $departmentLabel';
}

/// Firestore admin paths:
/// `institutions/{institutionId}/departments/{departmentId}/course_templates/{id}`.
///
/// Accepts the same [Course] / [GradeNode] shape as the user editor; scores are stripped
/// before writing so templates stay grade-free.
class AdminService {
  AdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _authService = authService;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuthService? _authService;

  CollectionReference<Map<String, dynamic>> _courseTemplates(
    String institutionId,
    String departmentId,
  ) {
    return _firestore
        .collection('institutions')
        .doc(institutionId)
        .collection('departments')
        .doc(departmentId)
        .collection('course_templates');
  }

  Future<void> _ensureTemplateAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No signed-in user');
    }
    if (_authService?.isAdmin() == true) {
      return;
    }
    final snap = await _firestore.collection('users').doc(uid).get();
    if (snap.data()?['isAdmin'] != true) {
      throw StateError('Not authorized to manage course templates');
    }
  }

  /// One-shot read (e.g. onboarding clone). No admin gate — relies on Firestore rules.
  Future<List<CourseTemplate>> fetchCourseTemplatesOnce({
    required String institutionId,
    required String departmentId,
  }) async {
    final snap = await _courseTemplates(institutionId, departmentId).get();
    final list = snap.docs.map(courseTemplateFromFirestoreDoc).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Watch all templates for a department (sorted by name in memory — no `orderBy` query).
  Stream<List<CourseTemplate>> watchCourseTemplates({
    required String institutionId,
    required String departmentId,
  }) {
    return _courseTemplates(institutionId, departmentId).snapshots().map((s) {
      final list = s.docs.map(courseTemplateFromFirestoreDoc).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// Single template doc for editor sync.
  Stream<CourseTemplate?> watchCourseTemplate({
    required String institutionId,
    required String departmentId,
    required String templateDocId,
  }) {
    return _courseTemplates(institutionId, departmentId).doc(templateDocId).snapshots().map((s) {
      if (!s.exists) {
        return null;
      }
      return courseTemplateFromFirestoreDoc(s);
    });
  }

  /// Documents in `institutions` (dropdown: [label] prefers field `name`, else doc id).
  Stream<List<({String id, String label})>> watchInstitutionPickList() {
    return _firestore.collection('institutions').snapshots().map((s) {
      final list = <({String id, String label})>[];
      for (final d in s.docs) {
        final rawName = (d.data()['name'] as String?)?.trim();
        list.add((id: d.id, label: (rawName == null || rawName.isEmpty) ? d.id : rawName));
      }
      list.sort((a, b) => a.label.compareTo(b.label));
      return list;
    });
  }

  /// [onlyReady] — למשתמשי Onboarding: רק מחלקות עם `isReady == true` במסמך `departments/{id}`.
  Stream<List<({String id, String label})>> watchDepartmentPickList(
    String institutionId, {
    bool onlyReady = false,
  }) {
    return _firestore
        .collection('institutions')
        .doc(institutionId)
        .collection('departments')
        .snapshots()
        .map((s) {
      final list = <({String id, String label})>[];
      for (final d in s.docs) {
        final data = d.data();
        final isReady = data['isReady'] as bool? ?? false;
        if (onlyReady && !isReady) {
          continue;
        }
        final rawName = (data['name'] as String?)?.trim();
        list.add((id: d.id, label: (rawName == null || rawName.isEmpty) ? d.id : rawName));
      }
      list.sort((a, b) => a.label.compareTo(b.label));
      return list;
    });
  }

  /// `isReady` on `institutions/{institutionId}/departments/{departmentId}` (default false).
  Future<bool> getDepartmentIsReadyOnce({
    required String institutionId,
    required String departmentId,
  }) async {
    final snap = await _firestore
        .collection('institutions')
        .doc(institutionId)
        .collection('departments')
        .doc(departmentId)
        .get();
    if (!snap.exists) {
      return false;
    }
    return snap.data()?['isReady'] as bool? ?? false;
  }

  /// One-shot list for "בחר תואר" (all published departments across institutions).
  Future<List<ReadyDepartmentOption>> fetchReadyDepartmentsOnce() async {
    final instSnap = await _firestore.collection('institutions').get();
    final out = <ReadyDepartmentOption>[];
    for (final instDoc in instSnap.docs) {
      final instNameRaw = (instDoc.data()['name'] as String?)?.trim();
      final instLabel =
          (instNameRaw == null || instNameRaw.isEmpty) ? instDoc.id : instNameRaw;
      final deptSnap = await instDoc.reference.collection('departments').get();
      for (final deptDoc in deptSnap.docs) {
        final data = deptDoc.data();
        if ((data['isReady'] as bool?) != true) {
          continue;
        }
        final deptNameRaw = (data['name'] as String?)?.trim();
        final deptLabel =
            (deptNameRaw == null || deptNameRaw.isEmpty) ? deptDoc.id : deptNameRaw;
        out.add(
          ReadyDepartmentOption(
            institutionId: instDoc.id,
            institutionLabel: instLabel,
            departmentId: deptDoc.id,
            departmentLabel: deptLabel,
          ),
        );
      }
    }
    out.sort((a, b) => a.displayName.compareTo(b.displayName));
    return out;
  }

  Stream<bool> watchDepartmentIsReady({
    required String institutionId,
    required String departmentId,
  }) {
    return _firestore
        .collection('institutions')
        .doc(institutionId)
        .collection('departments')
        .doc(departmentId)
        .snapshots()
        .map((s) {
      if (!s.exists) {
        return false;
      }
      return s.data()?['isReady'] as bool? ?? false;
    });
  }

  /// מסמן שהתואר מוכן להופיע ב-Onboarding (אדמין בלבד).
  Future<void> setDepartmentReady({
    required String institutionId,
    required String departmentId,
    required bool isReady,
  }) async {
    await _ensureTemplateAdmin();
    await _firestore
        .collection('institutions')
        .doc(institutionId)
        .collection('departments')
        .doc(departmentId)
        .set(<String, dynamic>{
          'isReady': isReady,
          'publishedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  /// Builds a [CourseTemplate] from editor state: [structureRoot] if non-null, else [course.rootNode].
  /// Scores are cleared — safe to persist under [course_templates].
  static CourseTemplate courseTemplateFromCourseDraft({
    required String documentId,
    required UserCourse course,
    GradeNode? structureRoot,
    required int version,
  }) {
    final bareRoot = stripScoresForTemplate(structureRoot ?? course.rootNode);
    return CourseTemplate(
      id: documentId,
      templateId: documentId,
      name: course.name.trim(),
      credits: course.credits,
      structureRoot: bareRoot,
      isPassFail: course.isPassFail,
      academicYear: course.academicYear,
      semester: course.semester,
      finalBonus: course.finalBonus,
      moedBPolicy: course.moedBPolicy,
      fastGrading: false,
      version: version,
      lastUpdated: null,
    );
  }

  /// Creates a new template document. Returns the new document id.
  Future<String> createCourseTemplateFromCourse({
    required String institutionId,
    required String departmentId,
    required UserCourse course,
    GradeNode? structureRoot,
  }) async {
    await _ensureTemplateAdmin();
    final ref = _courseTemplates(institutionId, departmentId).doc();
    final template = courseTemplateFromCourseDraft(
      documentId: ref.id,
      course: course,
      structureRoot: structureRoot,
      version: 1,
    );
    final map = courseTemplateToFirestoreMap(template);
    map['lastUpdated'] = FieldValue.serverTimestamp();
    await ref.set(map);
    return ref.id;
  }

  /// Overwrites an existing template from editor [Course] state (or optional [structureRoot]).
  Future<void> updateCourseTemplateFromCourse({
    required String institutionId,
    required String departmentId,
    required String templateDocId,
    required UserCourse course,
    GradeNode? structureRoot,
    bool bumpVersion = true,
  }) async {
    await _ensureTemplateAdmin();
    final ref = _courseTemplates(institutionId, departmentId).doc(templateDocId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('Template not found: $templateDocId');
    }
    final prev = (snap.data()?['version'] as num?)?.toInt() ?? 1;
    final nextVersion = bumpVersion ? prev + 1 : prev;
    final template = courseTemplateFromCourseDraft(
      documentId: templateDocId,
      course: course,
      structureRoot: structureRoot,
      version: nextVersion,
    );
    final map = courseTemplateToFirestoreMap(template);
    map['lastUpdated'] = FieldValue.serverTimestamp();
    await ref.set(map);
  }

  /// Persists only the grade structure (and bumps [lastUpdated]); keeps other fields as-is.
  Future<void> updateCourseTemplateRoot({
    required String institutionId,
    required String departmentId,
    required String templateDocId,
    required GradeNode rootNode,
    bool bumpVersion = true,
  }) async {
    await _ensureTemplateAdmin();
    final ref = _courseTemplates(institutionId, departmentId).doc(templateDocId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('Template not found: $templateDocId');
    }
    final data = snap.data() ?? {};
    final prevVersion = (data['version'] as num?)?.toInt() ?? 1;
    final nextVersion = bumpVersion ? prevVersion + 1 : prevVersion;
    final bare = stripScoresForTemplate(rootNode);
    await ref.update(<String, dynamic>{
      'rootNode': gradeNodeToMap(bare),
      'fastGrading': false,
      'version': nextVersion,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCourseTemplate({
    required String institutionId,
    required String departmentId,
    required String templateDocId,
  }) async {
    await _ensureTemplateAdmin();
    await _courseTemplates(institutionId, departmentId).doc(templateDocId).delete();
  }

  /// מחיקת כל מסמכי `course_templates` בחוג (אצווה עד 500 למחיקה).
  Future<int> deleteAllCourseTemplatesInDepartment({
    required String institutionId,
    required String departmentId,
  }) async {
    await _ensureTemplateAdmin();
    final snap = await _courseTemplates(institutionId, departmentId).get();
    if (snap.docs.isEmpty) {
      return 0;
    }
    const chunk = 500;
    var deleted = 0;
    for (var i = 0; i < snap.docs.length; i += chunk) {
      final batch = _firestore.batch();
      final end = (i + chunk > snap.docs.length) ? snap.docs.length : i + chunk;
      for (var j = i; j < end; j++) {
        batch.delete(snap.docs[j].reference);
      }
      await batch.commit();
      deleted += end - i;
    }
    return deleted;
  }

  /// לכל סטודנט עם אותו מוסד+חוג בפרופיל: מוסיף קורסים מהספרייה אם חסר [templateId] (לא דורס ציונים).
  Future<DepartmentTemplateSyncResult> syncMissingTemplatesToDepartmentStudents({
    required String institutionId,
    required String departmentId,
    required CourseFirestoreService courseService,
  }) async {
    await _ensureTemplateAdmin();
    final templates = await fetchCourseTemplatesOnce(
      institutionId: institutionId,
      departmentId: departmentId,
    );
    if (templates.isEmpty) {
      return const DepartmentTemplateSyncResult(
        studentCount: 0,
        coursesAdded: 0,
        coursesSkipped: 0,
      );
    }
    final usersSnap = await _firestore
        .collection('users')
        .where('institutionId', isEqualTo: institutionId)
        .get();
    var studentCount = 0;
    var added = 0;
    var skipped = 0;
    for (final userDoc in usersSnap.docs) {
      final data = userDoc.data();
      if (data['departmentId'] != departmentId) {
        continue;
      }
      studentCount++;
      final uid = userDoc.id;
      for (final t in templates) {
        final r = await courseService.cloneTemplateToUserIfMissing(
          targetUid: uid,
          template: t,
        );
        if (r.skippedDuplicate) {
          skipped++;
        } else {
          added++;
        }
      }
    }
    return DepartmentTemplateSyncResult(
      studentCount: studentCount,
      coursesAdded: added,
      coursesSkipped: skipped,
    );
  }
}

/// תוצאת [AdminService.syncMissingTemplatesToDepartmentStudents].
final class DepartmentTemplateSyncResult {
  const DepartmentTemplateSyncResult({
    required this.studentCount,
    required this.coursesAdded,
    required this.coursesSkipped,
  });

  final int studentCount;
  final int coursesAdded;
  final int coursesSkipped;
}
