import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_service.dart';
import '../services/course_firestore_service.dart';
import '../widgets/firestore_entity_picker.dart';

/// בחירת מוסד וחוג, עדכון פרופיל, ושכפול כל תבניות הקורס ל-[users/{uid}/courses].
class DegreeSelectionScreen extends StatefulWidget {
  const DegreeSelectionScreen({super.key});

  @override
  State<DegreeSelectionScreen> createState() => _DegreeSelectionScreenState();
}

class _DegreeSelectionScreenState extends State<DegreeSelectionScreen> {
  String? _institutionId;
  String? _departmentId;
  bool _busy = false;

  String _friendlyLoadErrorMessage(Object error, {required String fallback}) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'אין הרשאת גישה לנתונים. וודא שאתה מחובר';
      }
      if (error.code == 'failed-precondition') {
        return 'חסר אינדקס במסד הנתונים. אנא פנה לאדמין';
      }
    }
    return '$fallback: $error';
  }

  Widget _buildLoadErrorCard(String message) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _onStart() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final inst = _institutionId?.trim();
    final dept = _departmentId?.trim();
    if (uid == null || inst == null || inst.isEmpty || dept == null || dept.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('נא לבחור מוסד וחוג')),
      );
      return;
    }
    final courses = context.read<CourseFirestoreService>();
    final admin = context.read<AdminService>();

    setState(() => _busy = true);
    try {
      final ready = await admin.getDepartmentIsReadyOnce(
        institutionId: inst,
        departmentId: dept,
      );
      if (!ready) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'החוג עדיין לא פורסם. בקש מהאדמין ללחוץ "פרסם תואר" במסך ניהול התבניות.',
              ),
            ),
          );
        }
        return;
      }
      final templates = await admin.fetchCourseTemplatesOnce(
        institutionId: inst,
        departmentId: dept,
      );
      for (final t in templates) {
        await courses.cloneTemplateToUser(uid, t);
      }
      await courses.updateUserInstitutionAndDepartment(
        uid: uid,
        institutionId: inst,
        departmentId: dept,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            templates.isEmpty
                ? 'הפרופיל עודכן. לא נמצאו תבניות קורס בחוג — אפשר להוסיף קורסים ידנית.'
                : 'התחלת לימודים: ${templates.length} קורסים נוספו',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final admin = context.read<AdminService>();

    return Scaffold(
      appBar: AppBar(title: const Text('בחירת תואר')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'בחרו את מוסד הלימודים והחוג שלכם. לאחר מכן נטען את מבנה הקורסים מהתבניות (ללא ציונים).',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                StreamBuilder<List<({String id, String label})>>(
                  stream: admin.watchInstitutionPickList(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return _buildLoadErrorCard(
                        _friendlyLoadErrorMessage(
                          snap.error!,
                          fallback: 'שגיאה בטעינת מוסדות',
                        ),
                      );
                    }
                    final opts = snap.data ?? const [];
                    return FirestoreEntityPicker(
                      label: 'מוסד לימודים',
                      options: opts,
                      selectedId: _institutionId,
                      emptyMessage:
                          'אין מסמכים ב-institutions — צור מוסד ב-Firestore',
                      onSelected: (id) => setState(() {
                        _institutionId = id;
                        _departmentId = null;
                      }),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (_institutionId != null)
                  StreamBuilder<List<({String id, String label})>>(
                    stream: admin.watchDepartmentPickList(
                      _institutionId!,
                      onlyReady: true,
                    ),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError) {
                        return _buildLoadErrorCard(
                          _friendlyLoadErrorMessage(
                            snap.error!,
                            fallback: 'שגיאה בטעינת חוגים',
                          ),
                        );
                      }
                      final opts = snap.data ?? const [];
                      return FirestoreEntityPicker(
                        label: 'חוג / מסלול (פורסמו בלבד)',
                        options: opts,
                        selectedId: _departmentId,
                        emptyMessage:
                            'אין חוגים מוכנים — האדמין צריך לפרסם תואר במסך ניהול התבניות',
                        onSelected: (id) => setState(() => _departmentId = id),
                      );
                    },
                  ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _busy ? null : _onStart,
                  child: const Text('התחל לימודים'),
                ),
              ],
            ),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
