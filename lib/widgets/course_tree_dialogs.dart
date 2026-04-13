import 'package:flutter/material.dart';
import 'package:grade_master/grade_master.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Returns new branch [GradeBranch] data via callback, or nothing if cancelled.
Future<void> showAddBranchDialog({
  required BuildContext context,
  required String parentLabel,
  required void Function(String name, double weight, bool equalWeightChildren)
  onAdd,
}) async {
  final nameController = TextEditingController();
  final weightController = TextEditingController(text: '1');
  var equalShare = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: Text('ענף חדש ב־$parentLabel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'שם (למשל מעבדות)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'משקל (יחסי לאחים אצל ההורה)',
                    border: OutlineInputBorder(),
                    helperText:
                        'המשקל של הקשת מההורה לענף הזה. לא חייב לסכם 100 עם ילדי ההורה',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: equalShare,
                  onChanged: (v) => setState(() => equalShare = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('חלק משקלים שווה'),
                  subtitle: Text(
                    'הילדים ישוקללו בשקלות (1/n). המשקלים השמורים ליד כל ילד יישמרו בפיירסטור אך לא ישפיעו על החישוב.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
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
              onPressed: () {
                final name = nameController.text.trim();
                final w = double.tryParse(
                  weightController.text.replaceAll(',', '.'),
                );
                if (name.isEmpty || w == null || w < 0) {
                  return;
                }
                Navigator.pop(ctx);
                onAdd(name, w, equalShare);
              },
              child: const Text('הוסף'),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showAddLeafDialog({
  required BuildContext context,
  required String parentLabel,
  required void Function(
    String name,
    double maxScore,
    double weight,
    double? score,
    double bonusPoints,
  )
  onAdd,
}) async {
  final nameController = TextEditingController();
  final maxController = TextEditingController(text: '100');
  final weightController = TextEditingController(text: '1');
  final scoreController = TextEditingController();
  final bonusController = TextEditingController(text: '0');

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('מטלה חדשה ב־$parentLabel'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'שם המטלה',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Text(
              'סולם הציון',
              style: Theme.of(
                ctx,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: maxController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'ציון מקסימלי — תקרת הסולם',
                hintText: 'למשל 100 או 10',
                helperText:
                    'הציון הגבוה ביותר האפשרי במטלה (למשל 100 למבחן, 10 לבוחן)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'הציון שלך',
              style: Theme.of(
                ctx,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: scoreController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'הציון שקיבלת (ביחס לסולם למעלה)',
                hintText: 'ריק אם עדיין לא ידוע',
                helperText:
                    'הזן את הציון בפועל (למשל 85 מתוך 100). השאר ריק אם אין עדיין ציון',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bonusController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'בונוס למטלה (נקודות)',
                helperText: 'נוסף אחרי נרמול המטלה (למשל פקטור +2)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'משקל (יחסי לאחים באותו ענף)',
                border: OutlineInputBorder(),
                helperText: 'לא חייב לסכם 100',
              ),
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
          onPressed: () {
            final name = nameController.text.trim();
            final maxS = double.tryParse(
              maxController.text.replaceAll(',', '.'),
            );
            final w = double.tryParse(
              weightController.text.replaceAll(',', '.'),
            );
            final scoreRaw = scoreController.text.trim();
            final score = scoreRaw.isEmpty
                ? null
                : double.tryParse(scoreRaw.replaceAll(',', '.'));
            final bonusPoints = double.tryParse(
              bonusController.text.replaceAll(',', '.'),
            );
            if (name.isEmpty ||
                maxS == null ||
                maxS <= 0 ||
                w == null ||
                w < 0 ||
                bonusPoints == null) {
              return;
            }
            Navigator.pop(ctx);
            onAdd(name, maxS, w, score, bonusPoints);
          },
          child: const Text('הוסף'),
        ),
      ],
    ),
  );
}

/// אישור מחיקת רכיב (כולל כל תתי־העץ אם זה ענף).
Future<bool> showDeleteNodeConfirmDialog({
  required BuildContext context,
  required String componentName,
  required bool isBranch,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('מחיקת רכיב'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('האם למחוק את "$componentName"?'),
          if (isBranch) ...[
            const SizedBox(height: 12),
            Text(
              'זהו ענף: כל התתי־ענפים והמטלות שבתוכו יימחקו.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('ביטול'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('מחק'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// עריכת שם, משקל (אם לא שורש), ולמטלה גם סולם וציון. לענף: אופציית חלוקה שווה.
Future<void> showEditNodeDetailsDialog({
  required BuildContext context,
  required GradeNode node,
  required double? incomingWeight,
  required Future<void> Function({
    required String name,
    required double? edgeWeight,
    double? maxScore,
    double? score,
    double? bonusPoints,
    double? moedBScore,
    bool? isMoedBActive,
    bool? equalWeightChildren,
  })
  onSave,
}) async {
  final isRoot = node.id == 'root';
  final leafNode = switch (node) {
    GradeLeaf(
      :final maxScore,
      :final score,
      :final bonusPoints,
      :final moedBScore,
      :final isMoedBActive,
    ) => (
      maxScore,
      score,
      bonusPoints,
      moedBScore,
      isMoedBActive,
    ),
    _ => null,
  };
  final isLeaf = leafNode != null;
  final isBranch = node is GradeBranch && !isLeaf;
  var equalShareBranch = switch (node) {
    GradeBranch(:final equalWeightChildren) => equalWeightChildren,
    _ => false,
  };

  final nameController = TextEditingController(text: node.name);
  final weightController = TextEditingController(
    text: incomingWeight?.toString() ?? '',
  );
  final maxController = TextEditingController(
    text: leafNode != null ? leafNode.$1.toString() : '',
  );
  final scoreController = TextEditingController(
    text: leafNode?.$2?.toString() ?? '',
  );
  final bonusController = TextEditingController(
    text: leafNode?.$3.toString() ?? '0',
  );
  final moedBController = TextEditingController(
    text: leafNode?.$4?.toString() ?? '',
  );
  var moedBActive = leafNode?.$5 ?? false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: Text(isLeaf ? 'עריכת מטלה' : 'עריכת ענף'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'שם הרכיב',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                if (!isRoot) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'משקל (יחסי לאחים אצל ההורה)',
                      helperText: 'משקל הקשת מההורה לרכיב הזה',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (isBranch && !isRoot) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: equalShareBranch,
                    onChanged: (v) =>
                        setState(() => equalShareBranch = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('חלק משקלים שווה'),
                    subtitle: Text(
                      'ילדי הענף יחושבו 1/n לפי מספר הילדים',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
                if (isLeaf) ...[
              const SizedBox(height: 16),
              Text(
                'סולם הציון',
                style: Theme.of(
                  ctx,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: maxController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'ציון מקסימלי — תקרת הסולם',
                  hintText: 'למשל 100 או 10',
                  helperText: 'הציון המקסימלי האפשרי במטלה (ה"מכנה" של הסולם)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'הציון שלך',
                style: Theme.of(
                  ctx,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: scoreController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'הציון שקיבלת (ביחס לסולם למעלה)',
                  hintText: 'ריק אם אין עדיין ציון',
                  helperText:
                      'הזן את הציון בפועל. השאר ריק אם אין עדיין ציון (מצב יחסי)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bonusController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'בונוס למטלה (נקודות)',
                  helperText: 'למשל פקטור +2',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => setState(() => moedBActive = !moedBActive),
                icon: Icon(
                  moedBActive ? Icons.event_available : Icons.event_repeat,
                ),
                label: Text(moedBActive ? 'בטל מועד ב' : 'הוסף מועד ב'),
              ),
              if (moedBActive) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: moedBController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'ציון מועד ב׳',
                    hintText: 'ריק אם עדיין אין ציון',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
                ],
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
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                double? edgeWeight;
                if (!isRoot) {
                  final w = double.tryParse(
                    weightController.text.replaceAll(',', '.'),
                  );
                  if (w == null || w < 0) {
                    return;
                  }
                  edgeWeight = w;
                }
                double? maxScore;
                double? score;
                double? bonusPoints;
                double? moedBScore;
                if (isLeaf) {
                  maxScore = double.tryParse(
                    maxController.text.replaceAll(',', '.'),
                  );
                  final scoreRaw = scoreController.text.trim();
                  score = scoreRaw.isEmpty
                      ? null
                      : double.tryParse(scoreRaw.replaceAll(',', '.'));
                  bonusPoints = double.tryParse(
                    bonusController.text.replaceAll(',', '.'),
                  );
                  if (maxScore == null || maxScore <= 0) {
                    return;
                  }
                  if (bonusPoints == null) {
                    return;
                  }
                  final moedBRaw = moedBController.text.trim();
                  moedBScore = moedBRaw.isEmpty
                      ? null
                      : double.tryParse(moedBRaw.replaceAll(',', '.'));
                  if (moedBRaw.isNotEmpty && moedBScore == null) {
                    return;
                  }
                }
                Navigator.pop(ctx);
                await onSave(
                  name: name,
                  edgeWeight: edgeWeight,
                  maxScore: maxScore,
                  score: score,
                  bonusPoints: bonusPoints,
                  moedBScore: moedBActive ? moedBScore : null,
                  isMoedBActive: isLeaf ? moedBActive : null,
                  equalWeightChildren:
                      isBranch && !isRoot ? equalShareBranch : null,
                );
              },
              child: const Text('שמור'),
            ),
          ],
        );
      },
    ),
  );
}

String newNodeId() => _uuid.v4();
