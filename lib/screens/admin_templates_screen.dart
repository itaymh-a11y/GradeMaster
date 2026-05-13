import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/degree_template_service.dart';
import '../src/degree_template.dart';
import 'template_editor_screen.dart';

class AdminTemplatesScreen extends StatelessWidget {
  const AdminTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    if (!auth.isAdmin()) {
      return const Scaffold(body: Center(child: Text('אין הרשאה למסך זה')));
    }
    final service = context.read<DegreeTemplateService>();
    return Scaffold(
      appBar: AppBar(title: const Text('ניהול תבניות')),
      body: StreamBuilder<List<DegreeTemplate>>(
        stream: service.watchAllTemplatesForAdmin(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('שגיאה: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final templates = snapshot.data ?? const <DegreeTemplate>[];
          if (templates.isEmpty) {
            return const Center(child: Text('אין עדיין תבניות'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final t = templates[index];
              return Card(
                child: ListTile(
                  title: Text(t.displayName),
                  subtitle: Text(
                    'סטטוס: ${t.status.name} | יעד נ״ז: ${t.degreeCreditsTarget.toStringAsFixed(1)} | גרסה ${t.version}',
                  ),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => TemplateEditorScreen(template: t),
                      ),
                    );
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit_meta') {
                        await _showEditTemplateMetaDialog(context, t);
                        return;
                      }
                      if (value == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('מחיקת תבנית'),
                            content: Text('למחוק את התבנית "${t.displayName}"?'),
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
                        await context.read<DegreeTemplateService>().deleteTemplate(
                          t.id,
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit_meta',
                        child: Text('ערוך מטא-דאטה'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('מחק תבנית')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTemplateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('תבנית חדשה'),
      ),
    );
  }

  Future<void> _showCreateTemplateDialog(BuildContext context) async {
    final degreeController = TextEditingController();
    final institutionController = TextEditingController();
    final cohortController = TextEditingController();
    final creditsController = TextEditingController();
    var status = DegreeTemplateStatus.draft;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('יצירת תבנית חדשה'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: degreeController,
                  decoration: const InputDecoration(labelText: 'שם תואר'),
                ),
                TextField(
                  controller: institutionController,
                  decoration: const InputDecoration(labelText: 'מוסד'),
                ),
                TextField(
                  controller: cohortController,
                  decoration: const InputDecoration(labelText: 'מחזור'),
                ),
                TextField(
                  controller: creditsController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'יעד נק״ז'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<DegreeTemplateStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'סטטוס'),
                  items: DegreeTemplateStatus.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => status = v);
                    }
                  },
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
                if (credits == null ||
                    degreeController.text.trim().isEmpty ||
                    institutionController.text.trim().isEmpty ||
                    cohortController.text.trim().isEmpty) {
                  return;
                }
                await context.read<DegreeTemplateService>().createTemplate(
                  degreeName: degreeController.text,
                  institutionName: institutionController.text,
                  cohortLabel: cohortController.text,
                  degreeCreditsTarget: credits,
                  status: status,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('צור'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTemplateMetaDialog(
    BuildContext context,
    DegreeTemplate template,
  ) async {
    final degreeController = TextEditingController(text: template.degreeName);
    final institutionController = TextEditingController(
      text: template.institutionName,
    );
    final cohortController = TextEditingController(text: template.cohortLabel);
    final creditsController = TextEditingController(
      text: template.degreeCreditsTarget.toString(),
    );
    var status = template.status;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('עריכת מטא-דאטה'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: degreeController,
                  decoration: const InputDecoration(labelText: 'שם תואר'),
                ),
                TextField(
                  controller: institutionController,
                  decoration: const InputDecoration(labelText: 'מוסד'),
                ),
                TextField(
                  controller: cohortController,
                  decoration: const InputDecoration(labelText: 'מחזור'),
                ),
                TextField(
                  controller: creditsController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'יעד נק״ז'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<DegreeTemplateStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'סטטוס'),
                  items: DegreeTemplateStatus.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => status = v);
                    }
                  },
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
                if (credits == null) {
                  return;
                }
                await context.read<DegreeTemplateService>().updateTemplateMeta(
                  templateId: template.id,
                  degreeName: degreeController.text,
                  institutionName: institutionController.text,
                  cohortLabel: cohortController.text,
                  degreeCreditsTarget: credits,
                  status: status,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('שמור'),
            ),
          ],
        ),
      ),
    );
  }
}
