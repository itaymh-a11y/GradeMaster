import 'package:flutter/material.dart';
import 'package:grade_master/grade_master.dart';
import 'package:provider/provider.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/course_firestore_service.dart';
import '../widgets/firestore_entity_picker.dart';
import 'course_detail_screen.dart';

bool _effectiveInstitutionalAdmin(AuthService auth, UserModel profile) {
  return auth.isAdmin() || profile.isAdmin;
}

class _DepartmentToolbar extends StatelessWidget {
  const _DepartmentToolbar({
    required this.institutionId,
    required this.departmentId,
    required this.actionBusy,
    required this.onPublish,
    required this.onUnpublish,
    required this.onSyncMissingToStudents,
    required this.onDeleteAllTemplates,
  });

  final String institutionId;
  final String departmentId;
  final bool actionBusy;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onSyncMissingToStudents;
  final VoidCallback onDeleteAllTemplates;

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminService>();
    final theme = Theme.of(context);
    return StreamBuilder<bool>(
      stream: admin.watchDepartmentIsReady(
        institutionId: institutionId,
        departmentId: departmentId,
      ),
      builder: (context, snap) {
        final ready = snap.data ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ready)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'התואר פורסם — משתמשים חדשים רואים את החוג ב-Onboarding',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: actionBusy ? null : onPublish,
                icon: const Icon(Icons.publish),
                label: const Text('פרסם תואר'),
              ),
            if (ready) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: actionBusy ? null : onUnpublish,
                    icon: const Icon(Icons.unpublished_outlined),
                    label: const Text('בטל פרסום'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: actionBusy ? null : onSyncMissingToStudents,
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('הוסף קורסים חסרים לכל הסטודנטים'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'ספריית תבניות',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: actionBusy ? null : onDeleteAllTemplates,
              icon: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
              label: Text(
                'מחק את כל תבניות הקורס בחוג',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// צפייה, עריכה ומחיקה על `course_templates` לפי מוסד + חוג.
class InstitutionTemplatesAdminScreen extends StatelessWidget {
  const InstitutionTemplatesAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('לא מחובר')));
    }
    final courseService = context.read<CourseFirestoreService>();
    return StreamBuilder<UserModel>(
      stream: courseService.watchUserModel(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = snap.data ?? UserModel(uid: uid);
        if (!_effectiveInstitutionalAdmin(auth, profile)) {
          return Scaffold(
            appBar: AppBar(title: const Text('תבניות מוסד')),
            body: const Center(child: Text('אין הרשאה למסך זה')),
          );
        }
        return const _InstitutionTemplatesBody();
      },
    );
  }
}

class _InstitutionTemplatesBody extends StatefulWidget {
  const _InstitutionTemplatesBody();

  @override
  State<_InstitutionTemplatesBody> createState() => _InstitutionTemplatesBodyState();
}

class _InstitutionTemplatesBodyState extends State<_InstitutionTemplatesBody> {
  String? _institutionId;
  String? _departmentId;
  bool _actionBusy = false;

  Future<void> _withActionBusy(Future<void> Function() fn) async {
    setState(() => _actionBusy = true);
    try {
      await fn();
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Future<void> _onPublishDegree() async {
    final admin = context.read<AdminService>();
    final i = _institutionId!;
    final d = _departmentId!;
    try {
      await admin.setDepartmentReady(
        institutionId: i,
        departmentId: d,
        isReady: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('התואר פורסם בהצלחה')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('פרסום נכשל: $e')),
        );
      }
    }
  }

  Future<void> _onUnpublishDegree() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ביטול פרסום'),
        content: const Text(
          'החוג ייעלם ממסך בחירת התואר למשתמשים חדשים. סטודנטים קיימים לא יושפעו.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ביטול')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('בטל פרסום')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    final admin = context.read<AdminService>();
    try {
      await admin.setDepartmentReady(
        institutionId: _institutionId!,
        departmentId: _departmentId!,
        isReady: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('הפרסום בוטל')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה: $e')),
        );
      }
    }
  }

  Future<void> _onSyncMissingToStudents() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('סנכרון קורסים לסטודנטים'),
        content: const Text(
          'ייסרקו כל המשתמשים שבחרו את החוג הזה. לכל סטודנט יתווספו קורסים מהספרייה רק אם חסר אצלו קורס עם אותה תבנית — '
          'קורסים וציונים קיימים לא יידרסו.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ביטול')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('הרץ סנכרון')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    await _withActionBusy(() async {
      final admin = context.read<AdminService>();
      final courses = context.read<CourseFirestoreService>();
      try {
        final r = await admin.syncMissingTemplatesToDepartmentStudents(
          institutionId: _institutionId!,
          departmentId: _departmentId!,
          courseService: courses,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'סטודנטים שנסרקו: ${r.studentCount}. נוספו: ${r.coursesAdded}, כבר היו קיימים: ${r.coursesSkipped}',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('סנכרון נכשל: $e')),
          );
        }
      }
    });
  }

  Future<void> _onDeleteAllTemplates() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('מחיקת כל תבניות הקורס'),
        content: const Text(
          'כל מסמכי התבנית בחוג יימחקו מ-Firestore. קורסים שכבר נוצרו אצל סטודנטים לא יימחקו; '
          'מומלץ לבטל פרסום אחרי מחיקה אם אין יותר ספרייה.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ביטול')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('מחק הכל'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    await _withActionBusy(() async {
      final admin = context.read<AdminService>();
      try {
        final n = await admin.deleteAllCourseTemplatesInDepartment(
          institutionId: _institutionId!,
          departmentId: _departmentId!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('נמחקו $n תבניות')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('מחיקה נכשלה: $e')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminService>();
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('תבניות מוסד')),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('בחר מוסד וחוג', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    StreamBuilder<List<({String id, String label})>>(
                      stream: admin.watchInstitutionPickList(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Text('שגיאה בטעינת מוסדות: ${snap.error}');
                        }
                        final opts = snap.data ?? const [];
                        return FirestoreEntityPicker(
                          label: 'מוסד',
                          options: opts,
                          selectedId: _institutionId,
                          emptyMessage:
                              'אין מסמכים ב-institutions — צור מסמך מוסד ב-Firestore',
                          onSelected: (id) => setState(() {
                            _institutionId = id;
                            _departmentId = null;
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_institutionId != null)
                      StreamBuilder<List<({String id, String label})>>(
                        stream: admin.watchDepartmentPickList(_institutionId!),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Text('שגיאה בטעינת חוגים: ${snap.error}');
                          }
                          final opts = snap.data ?? const [];
                          return FirestoreEntityPicker(
                            label: 'חוג',
                            options: opts,
                            selectedId: _departmentId,
                            emptyMessage:
                                'אין מסמכים ב-departments — צור מסמך חוג תחת המוסד',
                            onSelected: (id) => setState(() => _departmentId = id),
                          );
                        },
                      ),
                    if (_institutionId != null && _departmentId != null) ...[
                      const SizedBox(height: 16),
                      _DepartmentToolbar(
                        institutionId: _institutionId!,
                        departmentId: _departmentId!,
                        actionBusy: _actionBusy,
                        onPublish: _actionBusy ? () {} : _onPublishDegree,
                        onUnpublish: _actionBusy ? () {} : _onUnpublishDegree,
                        onSyncMissingToStudents: _actionBusy ? () {} : _onSyncMissingToStudents,
                        onDeleteAllTemplates: _actionBusy ? () {} : _onDeleteAllTemplates,
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildTemplateList(admin)),
            ],
          ),
        ),
        if (_actionBusy)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildTemplateList(AdminService admin) {
    if (_institutionId == null || _departmentId == null) {
      return Center(
        child: Text(
          'בחרו מוסד וחוג כדי להציג תבניות',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final i = _institutionId!;
    final d = _departmentId!;
    return StreamBuilder<List<CourseTemplate>>(
      stream: admin.watchCourseTemplates(institutionId: i, departmentId: d),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('שגיאה: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return const Center(child: Text('אין תבניות קורס בספרייה זו'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final theme = Theme.of(context);
            final t = list[index];
            return Card(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => CourseDetailScreen.template(
                              institutionId: i,
                              departmentId: d,
                              templateDocId: t.id,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${t.academicYear.heLabel} • ${t.semester.heLabel} • '
                              'נ״ז: ${t.credits} • גרסה ${t.version} • ${t.templateId}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'פעולות',
                    icon: const Icon(Icons.more_vert),
                    onPressed: () async {
                      final value = await showModalBottomSheet<String>(
                        context: context,
                        showDragHandle: true,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: const Text('מחק תבנית'),
                                onTap: () => Navigator.pop(ctx, 'delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (value != 'delete' || !context.mounted) {
                        return;
                      }
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('מחיקת תבנית'),
                          content: Text('למחוק את "${t.name}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('ביטול'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('מחק'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !context.mounted) {
                        return;
                      }
                      try {
                        await admin.deleteCourseTemplate(
                          institutionId: i,
                          departmentId: d,
                          templateDocId: t.id,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('מחיקה נכשלה: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
