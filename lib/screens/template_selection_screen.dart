import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_service.dart';
import '../services/course_firestore_service.dart';

class TemplateSelectionScreen extends StatefulWidget {
  const TemplateSelectionScreen({super.key});

  @override
  State<TemplateSelectionScreen> createState() => _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends State<TemplateSelectionScreen> {
  bool _isApplying = false;
  List<ReadyDepartmentOption>? _readyDepartments;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadReadyDepartments();
  }

  Future<void> _loadReadyDepartments() async {
    setState(() {
      _loadError = null;
    });
    try {
      final ready = await context.read<AdminService>().fetchReadyDepartmentsOnce();
      if (!mounted) {
        return;
      }
      setState(() => _readyDepartments = ready);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _loadError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('בחירת תבנית תואר')),
      body: Stack(
        children: [
          if (_readyDepartments == null && _loadError == null)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'שגיאה בטעינת תארים:\n$_loadError',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _loadReadyDepartments,
                      icon: const Icon(Icons.refresh),
                      label: const Text('נסה שוב'),
                    ),
                  ],
                ),
              ),
            )
          else if ((_readyDepartments ?? const <ReadyDepartmentOption>[]).isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'אין כרגע תבניות תואר זמינות.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _readyDepartments!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final option = _readyDepartments![index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: Text(option.displayName),
                    subtitle: Text(
                      'מוסד: ${option.institutionLabel} | חוג: ${option.departmentLabel}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _isApplying
                        ? null
                        : () => _onDepartmentSelected(option: option),
                  ),
                );
              },
            ),
          if (_isApplying)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onDepartmentSelected({
    required ReadyDepartmentOption option,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final mode = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('בחירת אופן ייבוא'),
        content: const Text(
          'נמצא תואר שפורסם. האם להחליף את כל הקורסים הקיימים שלך (Replace), או להוסיף את קורסי התבנית לקיימים (Merge)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ביטול'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Merge'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) {
      return;
    }

    setState(() => _isApplying = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw StateError('No signed-in user');
      }
      final admin = context.read<AdminService>();
      final courses = context.read<CourseFirestoreService>();
      final templates = await admin.fetchCourseTemplatesOnce(
        institutionId: option.institutionId,
        departmentId: option.departmentId,
      );
      var deleted = 0;
      if (mode) {
        deleted = await courses.deleteAllCoursesForCurrentUser();
      }
      var imported = 0;
      for (final t in templates) {
        final r = await courses.cloneTemplateToUser(uid, t);
        if (!r.skippedDuplicate) {
          imported += 1;
        }
      }
      await courses.updateUserInstitutionAndDepartment(
        uid: uid,
        institutionId: option.institutionId,
        departmentId: option.departmentId,
      );
      if (!mounted) {
        return;
      }
      final modeLabel = mode ? 'Replace' : 'Merge';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'ייבוא הושלם ($modeLabel): נוספו $imported קורסים'
            '${deleted > 0 ? ', נמחקו $deleted' : ''}.',
          ),
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('ייבוא תבנית נכשל: $e')));
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }
}
