import 'package:flutter/material.dart';
import 'package:grade_master/grade_master.dart';
import 'package:provider/provider.dart';

import '../services/degree_template_service.dart';

class TemplateEditorScreen extends StatelessWidget {
  const TemplateEditorScreen({super.key, required this.template});

  final DegreeTemplate template;

  @override
  Widget build(BuildContext context) {
    final service = context.read<DegreeTemplateService>();
    return Scaffold(
      appBar: AppBar(title: Text('עריכת תבנית: ${template.degreeName}')),
      body: StreamBuilder<List<Course>>(
        stream: service.watchTemplateCourses(template.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('שגיאה: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final courses = snapshot.data ?? const <Course>[];
          if (courses.isEmpty) {
            return const Center(child: Text('אין קורסים בתבנית'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = courses[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(c.name),
                  subtitle: Text(
                    'נק״ז: ${c.credits.toStringAsFixed(1)}'
                    '${c.fastGrading ? ' | Fast Grading' : ''}',
                  ),
                  trailing: IconButton(
                    tooltip: 'מחק קורס מהתבנית',
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () async {
                      await context
                          .read<DegreeTemplateService>()
                          .deleteTemplateCourse(
                            templateId: template.id,
                            courseId: c.id,
                          );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTemplateCourseDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('הוסף קורס לתבנית'),
      ),
    );
  }

  Future<void> _showAddTemplateCourseDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final creditsController = TextEditingController();
    var fastGrading = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('קורס חדש לתבנית'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'שם הקורס'),
                ),
                TextField(
                  controller: creditsController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'נק״ז'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Fast Grading (ציון סופי בלבד)'),
                  subtitle: const Text('מאפשר הזנת ציון אחד מהיר בקורס הזה'),
                  value: fastGrading,
                  onChanged: (v) => setState(() => fastGrading = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ביטול'),
            ),
            FilledButton(
              onPressed: () async {
                final credits = double.tryParse(
                  creditsController.text.replaceAll(',', '.'),
                );
                if (nameController.text.trim().isEmpty || credits == null) {
                  return;
                }
                await context.read<DegreeTemplateService>().addTemplateCourse(
                  templateId: template.id,
                  name: nameController.text,
                  credits: credits,
                  fastGrading: fastGrading,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('הוסף'),
            ),
          ],
        ),
      ),
    );
  }
}
