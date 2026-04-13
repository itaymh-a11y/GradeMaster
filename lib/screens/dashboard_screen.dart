import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grade_master/grade_master.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/course_firestore_service.dart';
import '../services/simulation_service.dart';
import '../utils/grade_format.dart';
import 'analytics_screen.dart';
import 'course_detail_screen.dart';
import '../widgets/add_course_dialog.dart';

String _formatCredits(double c) {
  if ((c - c.round()).abs() < 1e-9) {
    return c.toInt().toString();
  }
  return c.toStringAsFixed(1);
}

/// Dashboard: live course list from Firestore and add-course FAB.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  CalculationMode _mode = CalculationMode.strict;
  AcademicYear? _yearFilter;
  SemesterKind? _semesterFilter;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final simulation = context.watch<SimulationService>();
    final email = user?.email ?? '';
    final uid = user?.uid;
    final simBarColor = simulation.enabled ? Colors.deepPurple : null;
    final simTextColor = simulation.enabled ? Colors.white : null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text('GradeMaster'),
          ],
        ),
        backgroundColor: simBarColor,
        foregroundColor: simTextColor,
        bottom: simulation.enabled
            ? const PreferredSize(
                preferredSize: Size.fromHeight(28),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Simulation Mode - Changes not saved'),
                ),
              )
            : null,
        actions: [
          IconButton(
            tooltip: simulation.enabled ? 'כבה סימולציה' : 'הפעל סימולציה',
            icon: Icon(
              simulation.enabled ? Icons.science : Icons.science_outlined,
            ),
            onPressed: () => simulation.toggle(),
          ),
          IconButton(
            tooltip: 'סטטיסטיקה',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const AnalyticsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'התנתקות',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('אין משתמש מחובר'))
          : StreamBuilder<List<Course>>(
              stream: context.read<CourseFirestoreService>().watchCourses(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'שגיאה בטעינת קורסים:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final courses = snapshot.data ?? [];
                final effectiveCourses = courses
                    .map(simulation.resolveCourseOrNull)
                    .whereType<Course>()
                    .toList();
                if (effectiveCourses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            email.isNotEmpty ? 'שלום, $email' : 'שלום',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'עדיין אין קורסים. לחץ על + כדי להוסיף.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return StreamBuilder<double?>(
                  stream: context.read<CourseFirestoreService>().watchDegreeCreditsTarget(uid),
                  builder: (context, targetSnapshot) {
                    final targetCredits = targetSnapshot.data;
                    final filtered = effectiveCourses.where((c) {
                      if (_yearFilter != null && c.academicYear != _yearFilter) {
                        return false;
                      }
                      if (_semesterFilter != null && c.semester != _semesterFilter) {
                        return false;
                      }
                      return true;
                    }).toList();
                    filtered.sort(_compareCourseChronological);
                    final dashboardGpa = computeCumulativeGpa(effectiveCourses, _mode);
                    final accumulatedCredits = effectiveCourses
                        .where(
                          (c) =>
                              computeCourseNormalizedGrade(
                                c,
                                CalculationMode.proportional,
                              ) != null,
                        )
                        .fold<double>(0.0, (s, c) => s + c.credits);
                    final totalCredits = effectiveCourses.fold<double>(
                      0.0,
                      (s, c) => s + c.credits,
                    );
                    final progressValue = targetCredits == null || targetCredits <= 0
                        ? null
                        : (accumulatedCredits / targetCredits).clamp(0.0, 1.0);
                    final listItems = _buildDashboardItems(filtered, _mode);
                    return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          'שלום, $email',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SegmentedButton<CalculationMode>(
                        segments: const [
                          ButtonSegment(
                            value: CalculationMode.strict,
                            label: Text('Strict'),
                          ),
                          ButtonSegment(
                            value: CalculationMode.proportional,
                            label: Text('יחסי'),
                          ),
                        ],
                        selected: <CalculationMode>{_mode},
                        emptySelectionAllowed: false,
                        showSelectedIcon: false,
                        onSelectionChanged: (s) =>
                            setState(() => _mode = s.first),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<AcademicYear?>(
                              initialValue: _yearFilter,
                              decoration: const InputDecoration(
                                labelText: 'שנה',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<AcademicYear?>(
                                  value: null,
                                  child: Text('כל השנים'),
                                ),
                                ...AcademicYear.values.map(
                                  (y) => DropdownMenuItem<AcademicYear?>(
                                    value: y,
                                    child: Text(y.heLabel),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() => _yearFilter = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<SemesterKind?>(
                              initialValue: _semesterFilter,
                              decoration: const InputDecoration(
                                labelText: 'סמסטר',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<SemesterKind?>(
                                  value: null,
                                  child: Text('כל הסמסטרים'),
                                ),
                                ...SemesterKind.values.map(
                                  (s) => DropdownMenuItem<SemesterKind?>(
                                    value: s,
                                    child: Text(s.heLabel),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _semesterFilter = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.teal.shade500,
                              Colors.teal.shade700,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: const Text(
                            'ממוצע תואר כללי',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${_mode == CalculationMode.strict ? 'מחושב במצב Strict' : 'מחושב במצב יחסי'}'
                            '${(_yearFilter != null || _semesterFilter != null) ? '\nמציג ${filtered.length} קורסים מתוך ${effectiveCourses.length}' : ''}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Text(
                            formatGradePercent(dashboardGpa),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: ListTile(
                          title: const Text('נקודות זכות'),
                          subtitle: Text(
                            targetCredits == null
                                ? 'נצברו: ${_formatCredits(accumulatedCredits)} / ${_formatCredits(totalCredits)}'
                                : 'נצברו: ${_formatCredits(accumulatedCredits)} / יעד ${_formatCredits(targetCredits)}',
                          ),
                          trailing: IconButton(
                            tooltip: 'ערוך יעד נ״ז',
                            icon: const Icon(Icons.tune),
                            onPressed: () => _showTargetCreditsDialog(
                              context,
                              uid: uid,
                              initial: targetCredits,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (progressValue != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                        child: LinearProgressIndicator(value: progressValue),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: listItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final row = listItems[index];
                          if (row.yearHeader != null) {
                            return Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 4,
                                end: 4,
                                top: 12,
                              ),
                              child: Text(
                                '${row.yearHeader!} | ממוצע שנתי: ${formatGradePercent(row.yearGpa)}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.teal.shade800,
                                    ),
                              ),
                            );
                          }
                          if (row.header != null) {
                            return Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 4,
                                end: 4,
                                top: 6,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.header!,
                                    style: Theme.of(context).textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ממוצע סמסטר: ${formatGradePercent(row.semesterGpa)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final course = row.course!;
                          final normalized = computeCourseNormalizedGrade(
                            course,
                            _mode,
                          );
                          final baseNormalized = computeNormalizedGrade(
                            course.rootNode,
                            _mode,
                            moedBPolicy: course.moedBPolicy,
                          );
                          final percentLabel = formatGradePercent(normalized);
                          final basePercentLabel = formatGradePercent(
                            baseNormalized,
                          );
                          final closedPortion = computeStrictClosedPortion(
                            course.rootNode,
                          );
                          final gradeColor = _courseGradeColor(
                            context,
                            course: course,
                            normalized: normalized,
                          );
                          return Card(
                            elevation: 1.5,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: gradeColor.withValues(alpha: 0.45),
                                width: 1.2,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        CourseDetailScreen(courseId: course.id),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.school_outlined,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            course.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: gradeColor,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              minHeight: 6,
                                              value: closedPortion,
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.teal.shade500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              Chip(
                                                label: Text(
                                                  'נ״ז: ${_formatCredits(course.credits)}',
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              if (course.isPassFail)
                                                Chip(
                                                  label: const Text(
                                                    'עובר/נכשל',
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              Chip(
                                                label: Text(course.academicYear.heLabel),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              Chip(
                                                label: Text(course.semester.heLabel),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              if (course.finalBonus != 0)
                                                Chip(
                                                  label: Text(
                                                    'בונוס קורס: ${course.finalBonus.toStringAsFixed(2)}',
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle_outline,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'הוזן ${formatGradePercent(closedPortion)}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          tooltip: 'ערוך קורס',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _showEditCourseDialog(
                                            context,
                                            uid: uid,
                                            course: course,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'מחק קורס',
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                          onPressed: () =>
                                              _onDeleteCoursePressed(
                                                course: course,
                                              ),
                                        ),
                                        Text(
                                          'ציון',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          percentLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: gradeColor,
                                              ),
                                        ),
                                        if (course.finalBonus != 0)
                                          Text(
                                            '$basePercentLabel + ${course.finalBonus.toStringAsFixed(2)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: uid == null
            ? null
            : () {
                if (simulation.enabled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'במצב סימולציה לא ניתן להוסיף קורס חדש (השינויים לא נשמרים).',
                      ),
                    ),
                  );
                  return;
                }
                showAddCourseDialog(context);
              },
        tooltip: 'הוסף קורס',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showTargetCreditsDialog(
    BuildContext context, {
    required String uid,
    required double? initial,
  }) async {
    final controller = TextEditingController(
      text: initial == null ? '' : initial.toString(),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('יעד נ״ז לתואר'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'סה״כ נ״ז לתואר',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              if (v == null || v <= 0) {
                return;
              }
              final sim = context.read<SimulationService>();
              if (sim.enabled) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('במצב סימולציה יעד נ״ז לא נשמר.'),
                  ),
                );
                return;
              }
              await context.read<CourseFirestoreService>().updateDegreeCreditsTarget(
                uid: uid,
                targetCredits: v,
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditCourseDialog(
    BuildContext context, {
    required String uid,
    required Course course,
  }) async {
    final nameController = TextEditingController(text: course.name);
    final creditsController = TextEditingController(
      text: course.credits.toString(),
    );
    final bonusController = TextEditingController(
      text: course.finalBonus.toString(),
    );
    var passFail = course.isPassFail;
    var year = course.academicYear;
    var semester = course.semester;
    var moedBPolicy = course.moedBPolicy;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('עריכת קורס'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'שם הקורס',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: creditsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'נקודות זכות',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bonusController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'בונוס סופי לקורס (נקודות)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('עובר / נכשל בלבד'),
                    value: passFail,
                    onChanged: (v) => setState(() => passFail = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AcademicYear>(
                    initialValue: year,
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
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => year = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SemesterKind>(
                    initialValue: semester,
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
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => semester = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MoedBPolicy>(
                    initialValue: moedBPolicy,
                    decoration: const InputDecoration(
                      labelText: 'מדיניות מועד ב׳',
                      border: OutlineInputBorder(),
                    ),
                    items: MoedBPolicy.values
                        .map(
                          (p) => DropdownMenuItem<MoedBPolicy>(
                            value: p,
                            child: Text(_moedBPolicyLabel(p)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => moedBPolicy = v);
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
                  final bonus = double.tryParse(
                    bonusController.text.replaceAll(',', '.'),
                  );
                  final name = nameController.text.trim();
                  if (name.isEmpty || credits == null || credits < 0 || bonus == null) {
                    return;
                  }
                  final sim = context.read<SimulationService>();
                  if (sim.enabled) {
                    sim.saveSimulatedCourse(
                      Course(
                        id: course.id,
                        name: name,
                        credits: credits,
                        rootNode: course.rootNode,
                        isPassFail: passFail,
                        academicYear: year,
                        semester: semester,
                        finalBonus: bonus,
                        moedBPolicy: moedBPolicy,
                      ),
                    );
                  } else {
                    await context.read<CourseFirestoreService>().updateCourseMeta(
                      uid: uid,
                      courseId: course.id,
                      name: name,
                      credits: credits,
                      isPassFail: passFail,
                      academicYear: year,
                      semester: semester,
                      finalBonus: bonus,
                      moedBPolicy: moedBPolicy,
                    );
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('שמור'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onDeleteCoursePressed({
    required Course course,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('אישור מחיקה'),
        content: Text(
          'האם אתה בטוח שברצונך למחוק את הקורס ${course.name}? '
          'פעולה זו תמחק את כל מבנה הציונים לצמיתות',
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
    if (ok != true || !mounted) {
      return;
    }
    try {
      final sim = context.read<SimulationService>();
      if (sim.enabled) {
        sim.deleteSimulatedCourse(course.id);
      } else {
        await context.read<CourseFirestoreService>().deleteCourse(course.id);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sim.enabled
                ? 'הקורס ${course.name} הוסר בסימולציה בלבד'
                : 'הקורס ${course.name} נמחק',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('מחיקת קורס נכשלה: $e')));
    }
  }
}

final class _DashboardRow {
  const _DashboardRow.yearHeader(this.yearHeader, this.yearGpa)
    : course = null,
      header = null,
      semesterGpa = null;
  const _DashboardRow.header(this.header, this.semesterGpa)
    : course = null,
      yearHeader = null,
      yearGpa = null;
  const _DashboardRow.course(this.course)
    : header = null,
      semesterGpa = null,
      yearHeader = null,
      yearGpa = null;

  final String? header;
  final Course? course;
  final double? semesterGpa;
  final String? yearHeader;
  final double? yearGpa;
}

int _compareCourseChronological(Course a, Course b) {
  final byYear = a.academicYear.index.compareTo(b.academicYear.index);
  if (byYear != 0) {
    return byYear;
  }
  final bySemester = _semesterOrder(a.semester).compareTo(
    _semesterOrder(b.semester),
  );
  if (bySemester != 0) {
    return bySemester;
  }
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

int _semesterOrder(SemesterKind s) {
  return switch (s) {
    SemesterKind.a => 0,
    SemesterKind.b => 1,
    SemesterKind.summer => 2,
  };
}

List<_DashboardRow> _buildDashboardItems(
  List<Course> sortedCourses,
  CalculationMode mode,
) {
  final out = <_DashboardRow>[];
  String? currentHeader;
  String? currentYearHeader;
  final semesterGroups = <String, List<Course>>{};
  final yearGroups = <String, List<Course>>{};
  for (final c in sortedCourses) {
    final header = '${c.academicYear.heLabel} - ${c.semester.heLabel}';
    final yearHeader = c.academicYear.heLabel;
    semesterGroups.putIfAbsent(header, () => <Course>[]).add(c);
    yearGroups.putIfAbsent(yearHeader, () => <Course>[]).add(c);
  }
  for (final c in sortedCourses) {
    final yearHeader = c.academicYear.heLabel;
    if (yearHeader != currentYearHeader) {
      currentYearHeader = yearHeader;
      out.add(
        _DashboardRow.yearHeader(
          yearHeader,
          computeWeightedGpa(yearGroups[yearHeader] ?? const [], mode),
        ),
      );
    }
    final header = '${c.academicYear.heLabel} - ${c.semester.heLabel}';
    if (header != currentHeader) {
      currentHeader = header;
      out.add(
        _DashboardRow.header(
          header,
          computeWeightedGpa(semesterGroups[header] ?? const [], mode),
        ),
      );
    }
    out.add(_DashboardRow.course(c));
  }
  return out;
}

Color _courseGradeColor(
  BuildContext context, {
  required Course course,
  required double? normalized,
}) {
  final colors = Theme.of(context).colorScheme;
  if (course.isPassFail || normalized == null) {
    return colors.onSurfaceVariant;
  }
  final grade100 = normalized * 100;
  if (grade100 >= 90) {
    return Colors.teal.shade400;
  }
  if (grade100 >= 75) {
    return Colors.amber.shade700;
  }
  if (grade100 >= 60) {
    return Colors.deepOrange.shade400;
  }
  return colors.error;
}

String _moedBPolicyLabel(MoedBPolicy policy) {
  return switch (policy) {
    MoedBPolicy.higher => 'הציון הגבוה קובע',
    MoedBPolicy.moedB => 'מועד ב׳ קובע',
  };
}
