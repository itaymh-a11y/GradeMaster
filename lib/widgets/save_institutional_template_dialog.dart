import 'package:flutter/material.dart';
import 'package:grade_master/grade_master.dart';
import 'package:provider/provider.dart';

import '../services/admin_service.dart';
import 'firestore_entity_picker.dart';

Future<void> showSaveInstitutionalTemplateDialog({
  required BuildContext context,
  required UserCourse sourceCourse,
}) async {
  final admin = context.read<AdminService>();
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return _SaveInstitutionalTemplateDialog(admin: admin, sourceCourse: sourceCourse);
    },
  );
}

class _SaveInstitutionalTemplateDialog extends StatefulWidget {
  const _SaveInstitutionalTemplateDialog({
    required this.admin,
    required this.sourceCourse,
  });

  final AdminService admin;
  final UserCourse sourceCourse;

  @override
  State<_SaveInstitutionalTemplateDialog> createState() =>
      _SaveInstitutionalTemplateDialogState();
}

class _SaveInstitutionalTemplateDialogState extends State<_SaveInstitutionalTemplateDialog> {
  final _manualInstCtrl = TextEditingController();
  final _manualDeptCtrl = TextEditingController();
  bool _useManualIds = false;
  String? _pickedInstitutionId;
  String? _pickedDepartmentId;

  @override
  void dispose() {
    _manualInstCtrl.dispose();
    _manualDeptCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final institutionId =
        _useManualIds ? _manualInstCtrl.text.trim() : _pickedInstitutionId;
    final departmentId =
        _useManualIds ? _manualDeptCtrl.text.trim() : _pickedDepartmentId;
    if (institutionId == null ||
        institutionId.isEmpty ||
        departmentId == null ||
        departmentId.isEmpty) {
      return;
    }
    try {
      final id = await widget.admin.createCourseTemplateFromCourse(
        institutionId: institutionId,
        departmentId: departmentId,
        course: widget.sourceCourse,
        structureRoot: widget.sourceCourse.rootNode,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('נשמרה תבנית מוסדית (מזהה: $id)')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שמירה נכשלה: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('שמור כתבנית מוסדית'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                title: const Text('הזנת מזהים ידנית'),
                subtitle: const Text(
                  'כשרשימות המוסד והחוג ריקות או מהירות הזנה',
                  style: TextStyle(fontSize: 12),
                ),
                value: _useManualIds,
                onChanged: (v) => setState(() => _useManualIds = v),
              ),
              if (_useManualIds) ...[
                TextField(
                  controller: _manualInstCtrl,
                  decoration: const InputDecoration(
                    labelText: 'מזהה מוסד (institution document id)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _manualDeptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'מזהה חוג (department document id)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                StreamBuilder<List<({String id, String label})>>(
                  stream: widget.admin.watchInstitutionPickList(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text('טעינת מוסדות נכשלה: ${snap.error}');
                    }
                    final opts = snap.data ?? const [];
                    return FirestoreEntityPicker(
                      label: 'מוסד',
                      options: opts,
                      selectedId: _pickedInstitutionId,
                      emptyMessage:
                          'אין מסמכים ב-institutions — צור מסמך מוסד או השתמש בהזנה ידנית',
                      onSelected: (id) => setState(() {
                        _pickedInstitutionId = id;
                        _pickedDepartmentId = null;
                      }),
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (_pickedInstitutionId != null)
                  StreamBuilder<List<({String id, String label})>>(
                    stream: widget.admin.watchDepartmentPickList(_pickedInstitutionId!),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Text('טעינת חוגים נכשלה: ${snap.error}');
                      }
                      final opts = snap.data ?? const [];
                      return FirestoreEntityPicker(
                        label: 'חוג',
                        options: opts,
                        selectedId: _pickedDepartmentId,
                        emptyMessage:
                            'אין מסמכים ב-departments — צור מסמך חוג או השתמש בהזנה ידנית',
                        onSelected: (id) => setState(() => _pickedDepartmentId = id),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
        FilledButton(onPressed: _submit, child: const Text('שמור')),
      ],
    );
  }
}
