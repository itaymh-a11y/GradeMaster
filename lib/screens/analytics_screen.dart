import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:grade_master/grade_master.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/course_firestore_service.dart';
import '../services/simulation_service.dart';
import '../utils/grade_format.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('סטטיסטיקה')),
        body: const Center(child: Text('לא מחובר')),
      );
    }
    final simulation = context.watch<SimulationService>();
    final coursesStream = context.read<CourseFirestoreService>().watchCourses(uid);
    final creditsTargetStream = context
        .read<CourseFirestoreService>()
        .watchDegreeCreditsTarget(uid);
    final gpaTargetStream = context.read<CourseFirestoreService>().watchDegreeGpaTarget(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('סטטיסטיקה ומגמות')),
      body: StreamBuilder<List<Course>>(
        stream: coursesStream,
        builder: (context, coursesSnap) {
          if (!coursesSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final effective = coursesSnap.data!
              .map(simulation.resolveCourseOrNull)
              .whereType<Course>()
              .toList()
            ..sort(_compareCourseChronological);
          return StreamBuilder<double?>(
            stream: creditsTargetStream,
            builder: (context, creditsTargetSnap) {
              return StreamBuilder<double?>(
                stream: gpaTargetStream,
                builder: (context, gpaTargetSnap) {
                  final creditsTarget = creditsTargetSnap.data;
                  final gpaTarget = gpaTargetSnap.data;
                  final sem = _semesterMetrics(effective);
                  final semesterCredits = _semesterCreditsDistribution(effective);
                  final currentGpa =
                      computeCumulativeGpa(effective, CalculationMode.strict);
                  final earnedCredits = effective
                      .where(
                        (c) => computeCourseNormalizedGrade(
                              c,
                              CalculationMode.proportional,
                            ) !=
                            null,
                      )
                      .fold<double>(0, (s, c) => s + c.credits);
                  final totalCredits = effective.fold<double>(
                    0,
                    (s, c) => s + c.credits,
                  );
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildGpaLineChart(context, sem),
                      const SizedBox(height: 12),
                      _buildCreditsPie(
                        context,
                        semesterCredits: semesterCredits,
                        earnedCredits: earnedCredits,
                        creditsTarget: creditsTarget,
                        fallbackTotal: totalCredits,
                      ),
                      const SizedBox(height: 12),
                      _buildInsightsCard(
                        context,
                        courses: effective,
                        sem: sem,
                        currentGpa: currentGpa,
                        targetGpa: gpaTarget,
                        uid: uid,
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

Widget _buildGpaLineChart(BuildContext context, List<_SemesterMetric> sem) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ממוצע תואר רב-סמסטריאלי'),
          const SizedBox(height: 4),
          Text(
            'ציר X: סמסטר | ציר Y: ממוצע',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: sem.isEmpty
                ? const Center(child: Text('אין מספיק נתונים להצגת גרף'))
                : LineChart(
                    LineChartData(
                      minX: -0.5,
                      maxX: sem.length - 0.5,
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          barWidth: 3,
                          color: Colors.teal.shade600,
                          spots: [
                            for (var i = 0; i < sem.length; i++)
                              FlSpot(i.toDouble(), sem[i].gpa * 100),
                          ],
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.teal.withValues(alpha: 0.30),
                                Colors.teal.withValues(alpha: 0.02),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: 20,
                            getTitlesWidget: (v, _) => Text(
                              v.toInt().toString(),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 86,
                            interval: 1,
                            getTitlesWidget: (v, meta) {
                              final i = v.round();
                              if ((v - i).abs() > 0.001) {
                                return const SizedBox.shrink();
                              }
                              if (i < 0 || i >= sem.length) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                meta: meta,
                                angle: -0.785398, // 45deg
                                space: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.teal.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    sem[i].shortLabel,
                                    textDirection: TextDirection.rtl,
                                    style: Theme.of(context).textTheme.labelSmall
                                        ?.copyWith(
                                          color: Colors.teal.shade900,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCreditsPie(
  BuildContext context, {
  required List<_SemesterCreditSlice> semesterCredits,
  required double earnedCredits,
  required double? creditsTarget,
  required double fallbackTotal,
}) {
  final target = (creditsTarget != null && creditsTarget > 0)
      ? creditsTarget
      : fallbackTotal;
  if (target <= 0) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('אין נתוני נ"ז להצגה'),
      ),
    );
  }
  final done = earnedCredits.clamp(0.0, target);
  final remain = (target - done).clamp(0.0, target);
  final palette = <Color>[
    Colors.teal.shade400,
    Colors.blueGrey.shade400,
    Colors.indigo.shade300,
    Colors.amber.shade400,
    Colors.deepOrange.shade300,
    Colors.purple.shade300,
  ];
  final slices = <_SemesterCreditSlice>[
    for (var i = 0; i < semesterCredits.length; i++)
      _SemesterCreditSlice(
        label: semesterCredits[i].label,
        credits: semesterCredits[i].credits,
        color: palette[i % palette.length],
      ),
  ];

  final sections = <PieChartSectionData>[
    for (final s in slices)
      PieChartSectionData(
        value: s.credits,
        color: s.color,
        title: '',
      ),
    if (remain > 0)
      PieChartSectionData(
        value: remain,
        color: Colors.grey.shade300,
        title: '',
      ),
  ];
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('התפלגות נקודות זכות'),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                height: 140,
                width: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    sections: sections,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${done.toStringAsFixed(1)} / ${target.toStringAsFixed(1)} נ"ז',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (slices.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final s in slices)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${s.label}: ${s.credits.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                if (remain > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'נותר ליעד: ${remain.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildInsightsCard(
  BuildContext context, {
  required List<Course> courses,
  required List<_SemesterMetric> sem,
  required double? currentGpa,
  required double? targetGpa,
  required String uid,
}) {
  final best = sem.isEmpty
      ? null
      : sem.reduce((a, b) => a.gpa >= b.gpa ? a : b);
  final improvedCount = courses.where(_hasMoedBImprovement).length;
  final heaviest = courses.isEmpty
      ? null
      : courses.reduce((a, b) => a.credits >= b.credits ? a : b);
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('תובנות חכמות'),
          const SizedBox(height: 8),
          Text(
            best == null
                ? 'הסמסטר הכי חזק שלך: אין נתונים'
                : 'הסמסטר הכי חזק שלך: ${best.label} (ממוצע ${(best.gpa * 100).toStringAsFixed(2)})',
          ),
          const SizedBox(height: 4),
          Text('כמה קורסים שיפרת במועד ב׳: $improvedCount'),
          const SizedBox(height: 4),
          Text(
            heaviest == null
                ? 'המקצוע עם המשקל הכי גבוה בתואר עד כה: —'
                : 'המקצוע עם המשקל הכי גבוה בתואר עד כה: ${heaviest.name}',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ממוצע תואר נוכחי: ${formatGradePercent(currentGpa)}'
                  '${targetGpa != null ? ' | יעד ממוצע תואר: ${targetGpa.toStringAsFixed(2)}' : ''}',
                ),
              ),
              IconButton(
                tooltip: 'ערוך יעד ממוצע תואר',
                onPressed: () => _showTargetGpaDialog(context, uid, targetGpa),
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> _showTargetGpaDialog(
  BuildContext context,
  String uid,
  double? initial,
) async {
  final c = TextEditingController(text: initial?.toStringAsFixed(2) ?? '');
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('יעד ממוצע תואר'),
      content: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'יעד ממוצע תואר (למשל 90)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
        FilledButton(
          onPressed: () async {
            final v = double.tryParse(c.text.replaceAll(',', '.'));
            if (v == null) {
              return;
            }
            await context.read<CourseFirestoreService>().updateDegreeGpaTarget(
              uid: uid,
              targetGpaPercent: v,
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

bool _hasMoedBImprovement(Course course) {
  bool improved = false;
  void walk(GradeNode node) {
    if (improved) {
      return;
    }
    switch (node) {
      case GradeLeaf(
        :final score,
        :final moedBScore,
        :final isMoedBActive,
      ):
        if (isMoedBActive &&
            moedBScore != null &&
            (score == null || moedBScore > score)) {
          improved = true;
        }
      case GradeBranch(:final children):
        for (final wc in children) {
          walk(wc.node);
        }
    }
  }

  walk(course.rootNode);
  return improved;
}

final class _SemesterMetric {
  const _SemesterMetric({
    required this.label,
    required this.shortLabel,
    required this.gpa,
  });

  final String label;
  final String shortLabel;
  final double gpa;
}

final class _SemesterCreditSlice {
  const _SemesterCreditSlice({
    required this.label,
    required this.credits,
    required this.color,
  });

  final String label;
  final double credits;
  final Color color;
}

List<_SemesterMetric> _semesterMetrics(List<Course> courses) {
  final grouped = <String, List<Course>>{};
  for (final c in courses) {
    final key = '${c.academicYear.name}_${c.semester.name}';
    grouped.putIfAbsent(key, () => <Course>[]).add(c);
  }
  final keys = grouped.keys.toList()
    ..sort((a, b) {
      final ap = a.split('_');
      final bp = b.split('_');
      final ay = AcademicYear.values.byName(ap[0]).index;
      final by = AcademicYear.values.byName(bp[0]).index;
      if (ay != by) {
        return ay.compareTo(by);
      }
      final as = _semesterOrder(SemesterKind.values.byName(ap[1]));
      final bs = _semesterOrder(SemesterKind.values.byName(bp[1]));
      return as.compareTo(bs);
    });
  final out = <_SemesterMetric>[];
  for (final key in keys) {
    final parts = key.split('_');
    final year = AcademicYear.values.byName(parts[0]);
    final sem = SemesterKind.values.byName(parts[1]);
    final gpa =
        computeWeightedGpa(grouped[key]!, CalculationMode.strict) ?? 0.0;
    out.add(
      _SemesterMetric(
        label: '${year.heLabel} ${sem.heLabel}',
        shortLabel: _shortSemesterLabel(year, sem),
        gpa: gpa,
      ),
    );
  }
  return out;
}

String _shortSemesterLabel(AcademicYear year, SemesterKind sem) {
  final yearLetter = switch (year) {
    AcademicYear.a => 'א',
    AcademicYear.b => 'ב',
    AcademicYear.c => 'ג',
    AcademicYear.d => 'ד',
  };
  final semToken = switch (sem) {
    SemesterKind.a => '1',
    SemesterKind.b => '2',
    SemesterKind.summer => 'קיץ',
  };
  return '$yearLetter-$semToken';
}

List<_SemesterCreditSlice> _semesterCreditsDistribution(List<Course> courses) {
  final grouped = <String, double>{};
  for (final c in courses) {
    final contributes = computeCourseNormalizedGrade(
          c,
          CalculationMode.proportional,
        ) !=
        null;
    if (!contributes) {
      continue;
    }
    final key = '${c.academicYear.heLabel} ${c.semester.heLabel}';
    grouped[key] = (grouped[key] ?? 0) + c.credits;
  }
  final entries = grouped.entries.toList()
    ..sort((a, b) {
      final ai = _semesterKeyOrder(a.key);
      final bi = _semesterKeyOrder(b.key);
      return ai.compareTo(bi);
    });
  return entries
      .map(
        (e) => _SemesterCreditSlice(
          label: e.key,
          credits: e.value,
          color: Colors.transparent,
        ),
      )
      .toList();
}

int _semesterKeyOrder(String keyLabel) {
  final years = AcademicYear.values;
  final semesters = SemesterKind.values;
  for (var y = 0; y < years.length; y++) {
    for (var s = 0; s < semesters.length; s++) {
      final label = '${years[y].heLabel} ${semesters[s].heLabel}';
      if (label == keyLabel) {
        return y * 10 + _semesterOrder(semesters[s]);
      }
    }
  }
  return 9999;
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
