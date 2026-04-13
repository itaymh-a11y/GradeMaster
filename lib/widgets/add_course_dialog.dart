import 'package:flutter/material.dart';
import 'package:grade_master/grade_master.dart';
import 'package:provider/provider.dart';

import '../services/course_firestore_service.dart';

Future<void> showAddCourseDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const _AddCourseDialogBody(),
  );
}

class _AddCourseDialogBody extends StatefulWidget {
  const _AddCourseDialogBody();

  @override
  State<_AddCourseDialogBody> createState() => _AddCourseDialogBodyState();
}

class _AddCourseDialogBodyState extends State<_AddCourseDialogBody> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _creditsController = TextEditingController();
  final _finalBonusController = TextEditingController(text: '0');
  bool _passFail = false;
  AcademicYear _year = AcademicYear.a;
  SemesterKind _semester = SemesterKind.a;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _creditsController.dispose();
    _finalBonusController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final credits = double.tryParse(
      _creditsController.text.replaceAll(',', '.'),
    );
    final finalBonus = double.tryParse(
      _finalBonusController.text.replaceAll(',', '.'),
    );
    if (credits == null || credits < 0 || finalBonus == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<CourseFirestoreService>().addCourse(
        name: _nameController.text,
        credits: credits,
        isPassFail: _passFail,
        academicYear: _year,
        semester: _semester,
        finalBonus: finalBonus,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('שמירה נכשלה: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('קורס חדש'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'שם הקורס',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'נא להזין שם';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _creditsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'נקודות זכות',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'נא להזין נ״ז';
                  }
                  final x = double.tryParse(v.replaceAll(',', '.'));
                  if (x == null || x < 0) {
                    return 'ערך לא תקין';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _finalBonusController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'בונוס סופי לקורס (נקודות)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'נא להזין בונוס (אפשר 0)';
                  }
                  final x = double.tryParse(v.replaceAll(',', '.'));
                  if (x == null) {
                    return 'ערך לא תקין';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('עובר / נכשל בלבד'),
                value: _passFail,
                onChanged: _saving
                    ? null
                    : (v) {
                        setState(() => _passFail = v);
                      },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AcademicYear>(
                initialValue: _year,
                decoration: const InputDecoration(
                  labelText: 'שנה',
                  border: OutlineInputBorder(),
                ),
                items: AcademicYear.values
                    .map(
                      (y) => DropdownMenuItem<AcademicYear>(
                        value: y,
                        child: Text(y.heLabel),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) {
                          setState(() => _year = v);
                        }
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SemesterKind>(
                initialValue: _semester,
                decoration: const InputDecoration(
                  labelText: 'סמסטר',
                  border: OutlineInputBorder(),
                ),
                items: SemesterKind.values
                    .map(
                      (s) => DropdownMenuItem<SemesterKind>(
                        value: s,
                        child: Text(s.heLabel),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) {
                          setState(() => _semester = v);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('ביטול'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('שמור'),
        ),
      ],
    );
  }
}
