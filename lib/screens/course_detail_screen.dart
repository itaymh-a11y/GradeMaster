import 'package:flutter/material.dart';
import 'package:grade_master/grade_master.dart';
import 'package:provider/provider.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/course_firestore_service.dart';
import '../services/simulation_service.dart';
import '../utils/grade_format.dart';
import '../widgets/course_tree_dialogs.dart';
import '../widgets/save_institutional_template_dialog.dart';

class _TreeRowItem {
  const _TreeRowItem({
    required this.node,
    required this.depth,
    this.incomingWeight,
    this.parentEqualWeight = false,
    this.siblingWeightSum,
    this.parentDirectChildCount,
  });

  final GradeNode node;
  final int depth;
  final double? incomingWeight;

  /// Whether the **parent** [GradeBranch] uses equal child weights.
  final bool parentEqualWeight;

  /// Σ משקלי אחים (הורה ידני); null אם שורש או הורה בשקלות שוות.
  final double? siblingWeightSum;

  /// מספר ילדים ישירים אצל ההורה (לתצוגת 1/n).
  final int? parentDirectChildCount;
}

List<_TreeRowItem> _flattenTree(GradeNode root) {
  final out = <_TreeRowItem>[];
  void visit(
    GradeNode node,
    int depth,
    double? edgeWeight,
    GradeBranch? parent,
  ) {
    double? sumW;
    final parentEq = parent?.equalWeightChildren ?? false;
    final parentN = parent?.children.length;
    if (parent != null && !parentEq) {
      sumW = parent.children.fold<double>(
        0.0,
        (s, c) => s + c.weight,
      );
    }
    out.add(
      _TreeRowItem(
        node: node,
        depth: depth,
        incomingWeight: edgeWeight,
        parentEqualWeight: parentEq,
        siblingWeightSum: sumW,
        parentDirectChildCount: parentN,
      ),
    );
    if (node is GradeBranch) {
      for (final wc in node.children) {
        visit(wc.node, depth + 1, wc.weight, node);
      }
    }
  }

  visit(root, 0, null, null);
  return out;
}

UserCourse _userCourseFromInstitutionalTemplate(CourseTemplate template) {
  return UserCourse(
    id: template.id,
    name: template.name,
    credits: template.credits,
    rootNode: deepCopyGradeNode(template.structureRoot),
    isPassFail: template.isPassFail,
    academicYear: template.academicYear,
    semester: template.semester,
    finalBonus: template.finalBonus,
    moedBPolicy: template.moedBPolicy,
    fastGrading: false,
    templateId: template.templateId,
  );
}

bool _canUploadInstitutionalTemplate({
  required AuthService auth,
  required UserModel? eagerProfile,
  required UserModel? streamProfile,
}) {
  return auth.isAdmin() ||
      (eagerProfile?.isAdmin == true) ||
      (streamProfile?.isAdmin == true);
}

/// עורץ עץ ציונים: קורס אישי ([CourseDetailScreen.user]) או תבנית ציבורית לפי נתיב ([CourseDetailScreen.template]).
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen._({
    super.key,
    this.userCourseId,
    this.institutionId,
    this.departmentId,
    this.templateDocId,
  }) : assert(
         (userCourseId != null &&
                 institutionId == null &&
                 departmentId == null &&
                 templateDocId == null) ||
             (userCourseId == null &&
                 institutionId != null &&
                 departmentId != null &&
                 templateDocId != null),
       );

  factory CourseDetailScreen.user({Key? key, required String courseId}) {
    return CourseDetailScreen._(key: key, userCourseId: courseId);
  }

  factory CourseDetailScreen.template({
    Key? key,
    required String institutionId,
    required String departmentId,
    required String templateDocId,
  }) {
    return CourseDetailScreen._(
      key: key,
      institutionId: institutionId,
      departmentId: departmentId,
      templateDocId: templateDocId,
    );
  }

  final String? userCourseId;
  final String? institutionId;
  final String? departmentId;
  final String? templateDocId;

  bool get isInstitutionalTemplateEditor =>
      institutionId != null && departmentId != null && templateDocId != null;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  static const CalculationMode _mode = CalculationMode.proportional;
  bool _writing = false;
  double? _targetGradePercent;

  /// טעינת `users/{uid}` לפני אירוע ראשון של [watchUserModel] — מניע חסימת UI על `isAdmin`.
  UserModel? _eagerUserProfile;

  @override
  void initState() {
    super.initState();
    if (widget.isInstitutionalTemplateEditor) {
      debugPrint(
        '[CourseDetailScreen] init institutional template doc=${widget.templateDocId}',
      );
    } else {
      debugPrint(
        '[CourseDetailScreen] init user course id=${widget.userCourseId}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadEagerUserProfileForAdmin();
      });
    }
  }

  Future<void> _loadEagerUserProfileForAdmin() async {
    if (!mounted || widget.isInstitutionalTemplateEditor) {
      return;
    }
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid;
    debugPrint(
      '[CourseDetailScreen] admin flags uid=$uid '
      'auth.isAdmin()=${auth.isAdmin()} '
      'matchesConfiguredAdminUid=${auth.matchesConfiguredAdminUid(uid)} '
      'configuredAdminUid=${auth.configuredAdminUid}',
    );
    if (uid == null) {
      return;
    }
    try {
      final m = await context.read<CourseFirestoreService>().getUserModelOnce(uid);
      debugPrint(
        '[CourseDetailScreen] Firestore getUserModelOnce '
        'isAdmin=${m.isAdmin} institutionId=${m.institutionId} departmentId=${m.departmentId}',
      );
      if (mounted) {
        setState(() => _eagerUserProfile = m);
      }
    } catch (e, st) {
      debugPrint('[CourseDetailScreen] getUserModelOnce failed: $e\n$st');
    }
  }

  Future<void> _persist(Course course, GradeNode newRoot) async {
    if (widget.isInstitutionalTemplateEditor) {
      setState(() => _writing = true);
      try {
        await context.read<AdminService>().updateCourseTemplateRoot(
              institutionId: widget.institutionId!,
              departmentId: widget.departmentId!,
              templateDocId: widget.templateDocId!,
              rootNode: newRoot,
            );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('שמירה נכשלה: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _writing = false);
        }
      }
      return;
    }

    final simulation = context.read<SimulationService>();
    if (simulation.enabled) {
      simulation.saveSimulatedRoot(base: course, rootNode: newRoot);
      return;
    }
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) {
      return;
    }
    setState(() => _writing = true);
    try {
      await context.read<CourseFirestoreService>().updateCourseRoot(
            uid: uid,
            courseId: course.id,
            rootNode: newRoot,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('שמירה נכשלה: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _writing = false);
      }
    }
  }

  Future<void> _persistFinalGradeOverride(
    Course course,
    String uid,
    SimulationService simulation,
    double? finalGradeOverride,
  ) async {
    setState(() => _writing = true);
    try {
      if (simulation.enabled) {
        simulation.saveSimulatedCourse(
          UserCourse(
            id: course.id,
            name: course.name,
            credits: course.credits,
            rootNode: course.rootNode,
            isPassFail: course.isPassFail,
            academicYear: course.academicYear,
            semester: course.semester,
            finalBonus: course.finalBonus,
            moedBPolicy: course.moedBPolicy,
            fastGrading: course.fastGrading,
            templateId: course.templateId,
            finalGradeOverride: finalGradeOverride,
          ),
        );
      } else {
        await context.read<CourseFirestoreService>().updateCourseFinalGradeOverride(
              uid: uid,
              courseId: course.id,
              finalGradeOverride: finalGradeOverride,
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('שמירה נכשלה: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _writing = false);
      }
    }
  }

  Future<void> _setFastGradingMode(
    String uid,
    CourseFirestoreService courses,
    String courseId,
    bool fastGrading,
  ) async {
    setState(() => _writing = true);
    try {
      await courses.setCourseFastGradingMode(
        uid: uid,
        courseId: courseId,
        fastGrading: fastGrading,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('עדכון נכשל: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _writing = false);
      }
    }
  }

  Future<void> _onDeleteNode(
    Course course,
    GradeNode node, {
    required bool isBranch,
  }) async {
    final ok = await showDeleteNodeConfirmDialog(
      context: context,
      componentName: node.name,
      isBranch: isBranch,
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      final newRoot = removeNodeById(course.rootNode, node.id);
      await _persist(course, newRoot);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('מחיקה נכשלה: $e')));
      }
    }
  }

  Future<void> _onEditNode(Course course, _TreeRowItem item) async {
    final node = item.node;
    await showEditNodeDetailsDialog(
      context: context,
      node: node,
      incomingWeight: item.incomingWeight,
      onSave:
          ({
            required String name,
            required double? edgeWeight,
            double? maxScore,
            double? score,
            double? bonusPoints,
            double? moedBScore,
            bool? isMoedBActive,
            bool? equalWeightChildren,
          }) async {
            var r = course.rootNode;
            if (node.id == 'root') {
              r = updateNodeName(r, node.id, name);
              await _persist(course, r);
              return;
            }
            if (node is GradeLeaf) {
              r = updateEdgeWeight(r, node.id, edgeWeight!);
              r = replaceNodeById(
                r,
                node.id,
                GradeLeaf(
                  id: node.id,
                  name: name,
                  maxScore: maxScore!,
                  score: score,
                  bonusPoints: bonusPoints ?? node.bonusPoints,
                  moedBScore: moedBScore ?? node.moedBScore,
                  isMoedBActive: isMoedBActive ?? node.isMoedBActive,
                ),
              );
            } else {
              final br = node as GradeBranch;
              r = updateEdgeWeight(r, node.id, edgeWeight!);
              r = replaceNodeById(
                r,
                node.id,
                GradeBranch(
                  id: br.id,
                  name: name,
                  equalWeightChildren:
                      equalWeightChildren ?? br.equalWeightChildren,
                  children: br.children,
                ),
              );
            }
            await _persist(course, r);
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isInstitutionalTemplateEditor) {
      return _buildInstitutionalTemplateRoute(context);
    }
    return _buildUserOwnedCourseRoute(context);
  }

  Widget _buildInstitutionalTemplateRoute(BuildContext context) {
    final simulation = context.watch<SimulationService>();
    final theme = Theme.of(context);
    return StreamBuilder<CourseTemplate?>(
      stream: context.read<AdminService>().watchCourseTemplate(
            institutionId: widget.institutionId!,
            departmentId: widget.departmentId!,
            templateDocId: widget.templateDocId!,
          ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('תבנית קורס')),
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('תבנית קורס')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final template = snapshot.data;
        if (template == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('תבנית קורס')),
            body: const Center(child: Text('התבנית לא נמצאה')),
          );
        }
        final course = _userCourseFromInstitutionalTemplate(template);
        return _courseEditorChrome(
          context,
          firebaseUserCourseForTemplateMenu: null,
          firebaseUserUid: null,
          simulation: simulation,
          titleText: template.name,
          institutionalEditBar: PreferredSize(
            preferredSize: const Size.fromHeight(36),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'עריכת תבנית מוסדית — שמירה ל-collection הציבורי',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
          institutionalTemplateRoute: true,
          course: course,
          effectiveCourse: course,
          courseFirestoreService: null,
          onFastGradingToggled: null,
          eagerUserProfile: null,
        );
      },
    );
  }

  Widget _buildUserOwnedCourseRoute(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid;
    final courseService = context.read<CourseFirestoreService>();
    final simulation = context.watch<SimulationService>();
    final simBarColor = simulation.enabled ? Colors.deepPurple : null;
    final simTextColor = simulation.enabled ? Colors.white : null;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('קורס'),
          backgroundColor: simBarColor,
          foregroundColor: simTextColor,
        ),
        body: const Center(child: Text('לא מחובר')),
      );
    }

    return StreamBuilder<Course?>(
      stream: courseService.watchCourse(uid, widget.userCourseId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('קורס'),
              backgroundColor: simBarColor,
              foregroundColor: simTextColor,
            ),
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('קורס'),
              backgroundColor: simBarColor,
              foregroundColor: simTextColor,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final course = snapshot.data;
        if (course == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('קורס'),
              backgroundColor: simBarColor,
              foregroundColor: simTextColor,
            ),
            body: const Center(child: Text('הקורס לא נמצא')),
          );
        }

        final effectiveCourse = simulation.resolveCourse(course);
        return _courseEditorChrome(
          context,
          firebaseUserCourseForTemplateMenu: course,
          firebaseUserUid: uid,
          simulation: simulation,
          titleText: course.name,
          institutionalEditBar: null,
          institutionalTemplateRoute: false,
          course: course,
          effectiveCourse: effectiveCourse,
          courseFirestoreService: courseService,
          onFastGradingToggled: (v) =>
              _setFastGradingMode(uid, courseService, course.id, v),
          eagerUserProfile: _eagerUserProfile,
        );
      },
    );
  }

  Widget _courseEditorChrome(
    BuildContext context, {
    required Course? firebaseUserCourseForTemplateMenu,
    required Course course,
    required Course effectiveCourse,
    required SimulationService simulation,
    required String titleText,
    required bool institutionalTemplateRoute,
    PreferredSizeWidget? institutionalEditBar,
    required CourseFirestoreService? courseFirestoreService,
    required String? firebaseUserUid,
    Future<void> Function(bool fastGrading)? onFastGradingToggled,
    UserModel? eagerUserProfile,
  }) {
    final simActive = institutionalTemplateRoute ? false : simulation.enabled;
    final simBarColor = simActive ? Colors.deepPurple : null;
    final simTextColor = simActive ? Colors.white : null;
    final effectiveRoot = effectiveCourse.rootNode;
    final rows = _flattenTree(effectiveRoot);
    final baseGrade = computeNormalizedGrade(
      effectiveRoot,
      _mode,
      moedBPolicy: effectiveCourse.moedBPolicy,
    );
    final grade = computeCourseNormalizedGrade(effectiveCourse, _mode);
    final gradeLabel = formatGradePercent(grade);
    final baseGradeLabel = formatGradePercent(baseGrade);
    final targetInsight = _computeTargetInsight(
      effectiveCourse,
      _targetGradePercent,
    );
    final theme = Theme.of(context);
    final auth = context.read<AuthService>();
    final hideTreeForFastFinal =
        !institutionalTemplateRoute && effectiveCourse.fastGrading;

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: simBarColor,
        foregroundColor: simTextColor,
        bottom: institutionalTemplateRoute
            ? institutionalEditBar
            : simActive
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Simulation Mode - Changes not saved'),
                    ],
                  ),
                ),
              )
            : null,
        actions: [
          if (!institutionalTemplateRoute) ...[
            IconButton(
              tooltip: simActive ? 'כבה סימולציה' : 'הפעל סימולציה',
              onPressed: () => simulation.toggle(),
              icon: Icon(
                simActive ? Icons.science : Icons.science_outlined,
              ),
            ),
          ],
          if (!institutionalTemplateRoute &&
              firebaseUserUid != null &&
              courseFirestoreService != null)
            StreamBuilder<UserModel>(
              stream: courseFirestoreService.watchUserModel(firebaseUserUid),
              builder: (context, snap) {
                final streamProfile = snap.data;
                final canUpload = !simActive &&
                    _canUploadInstitutionalTemplate(
                      auth: auth,
                      eagerProfile: eagerUserProfile,
                      streamProfile: streamProfile,
                    );
                if (!canUpload) {
                  return const SizedBox.shrink();
                }
                final source = firebaseUserCourseForTemplateMenu;
                return IconButton(
                  tooltip: 'שמור כתבנית מוסדית',
                  icon: Icon(
                    Icons.cloud_upload,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: source == null
                      ? null
                      : () async {
                          await showSaveInstitutionalTemplateDialog(
                            context: context,
                            sourceCourse: source,
                          );
                        },
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: ListTile(
                    title: const Text('ציון מצטבר בקורס'),
                    subtitle: Text(
                      hideTreeForFastFinal
                          ? 'מצב ציון סופי בלבד — הציון מבוסס על השדה שמילאת למטה'
                                '${effectiveCourse.finalBonus != 0 ? '\n$baseGradeLabel + ${effectiveCourse.finalBonus.toStringAsFixed(2)}' : ''}'
                          : 'יחסי: רק רכיבים עם ציון'
                                '${effectiveCourse.finalBonus != 0 ? '\n$baseGradeLabel + ${effectiveCourse.finalBonus.toStringAsFixed(2)}' : ''}',
                    ),
                    trailing: Text(
                      gradeLabel,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              if (!institutionalTemplateRoute &&
                  onFastGradingToggled != null &&
                  firebaseUserUid != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: SwitchListTile(
                    title: const Text('הזן ציון סופי בלבד'),
                    subtitle: const Text(
                      'מסתיר את מבנה העץ ומאפשר למלא ציון סופי (0–100) בלבד',
                    ),
                    value: effectiveCourse.fastGrading,
                    onChanged: simActive || _writing
                        ? null
                        : (v) {
                            onFastGradingToggled(v);
                          },
                  ),
                ),
              if (hideTreeForFastFinal && firebaseUserUid != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FinalGradeOverrideCard(
                    course: effectiveCourse,
                    busy: _writing,
                    onSave: (value) => _persistFinalGradeOverride(
                      effectiveCourse,
                      firebaseUserUid,
                      simulation,
                      value,
                    ),
                  ),
                ),
              if (!institutionalTemplateRoute && !hideTreeForFastFinal)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: ListTile(
                      title: Text(
                        _targetGradePercent == null
                            ? 'ציון יעד: לא הוגדר'
                            : 'ציון יעד: ${_targetGradePercent!.toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        targetInsight?.message ??
                            'הגדר יעד כדי לקבל חישוב "כמה צריך לקבל".',
                      ),
                      trailing: FilledButton.tonalIcon(
                        onPressed: () => _showTargetDialog(),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('הגדר יעד'),
                      ),
                    ),
                  ),
                ),
              if (hideTreeForFastFinal) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'מבנה הקורס מוסתר במצב זה. כבו את המתג "הזן ציון סופי בלבד" למעלה כדי לערוך את העץ.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'מבנה הציונים',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final item = rows[index];
                      return _buildRowTile(
                        context,
                        course: effectiveCourse,
                        item: item,
                        mode: _mode,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          if (_writing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }

  Widget _buildRowTile(
    BuildContext context, {
    required Course course,
    required _TreeRowItem item,
    required CalculationMode mode,
  }) {
    final theme = Theme.of(context);
    final node = item.node;
    final isRoot = node.id == 'root';
    final isBranch = node is GradeBranch;

    final Widget addMenu = switch (node) {
      GradeBranch(:final id, :final name) => PopupMenuButton<String>(
          enabled: !_writing,
          tooltip: 'הוסף',
          icon: const Icon(Icons.add_circle_outline),
          onSelected: (value) async {
            if (value == 'branch') {
              await showAddBranchDialog(
                context: context,
                parentLabel: name,
                onAdd: (childName, weight, equalW) {
                  final nid = newNodeId();
                  final child = GradeBranch(
                    id: nid,
                    name: childName,
                    children: const [],
                    equalWeightChildren: equalW,
                  );
                  final newRoot = addChildToBranch(
                    course.rootNode,
                    id,
                    WeightedChild(weight: weight, node: child),
                  );
                  _persist(course, newRoot);
                },
              );
            } else if (value == 'leaf') {
              await showAddLeafDialog(
                context: context,
                parentLabel: name,
                onAdd: (leafName, maxScore, weight, score, bonusPoints) {
                  final nid = newNodeId();
                  final leaf = GradeLeaf(
                    id: nid,
                    name: leafName,
                    maxScore: maxScore,
                    score: score,
                    bonusPoints: bonusPoints,
                  );
                  final newRoot = addChildToBranch(
                    course.rootNode,
                    id,
                    WeightedChild(weight: weight, node: leaf),
                  );
                  _persist(course, newRoot);
                },
              );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'branch', child: Text('הוסף ענף')),
            PopupMenuItem(value: 'leaf', child: Text('הוסף מטלה (עלה)')),
          ],
        ),
      _ => const SizedBox.shrink(),
    };

    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isRoot)
          IconButton(
            tooltip: 'מחק',
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            onPressed: _writing
                ? null
                : () => _onDeleteNode(course, node, isBranch: isBranch),
          ),
        IconButton(
          tooltip: 'ערוך פרטים',
          icon: const Icon(Icons.edit_outlined),
          onPressed: _writing ? null : () => _onEditNode(course, item),
        ),
        addMenu,
      ],
    );

    final indent = 12.0 * item.depth;
    final icon = node is GradeBranch
        ? Icons.account_tree_outlined
        : Icons.description_outlined;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, end: 12, bottom: 6),
      child: Card(
        elevation: isRoot ? 3 : (isBranch ? 1.8 : 0.8),
        color: isRoot
            ? Colors.teal.shade700
            : (isBranch ? Colors.teal.shade50 : theme.colorScheme.surface),
        child: ListTile(
          dense: node is GradeLeaf,
          leading: CircleAvatar(
            backgroundColor: isRoot
                ? Colors.teal.shade100
                : theme.colorScheme.primaryContainer,
            foregroundColor: isRoot
                ? Colors.teal.shade900
                : theme.colorScheme.onPrimaryContainer,
            child: Icon(icon, size: 22),
          ),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                node.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isRoot ? Colors.white : null,
                ),
              ),
              if (item.incomingWeight != null)
                Chip(
                  label: Text(_incomingWeightChipLabel(item)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  backgroundColor: isRoot
                      ? Colors.white.withValues(alpha: 0.2)
                      : null,
                ),
            ],
          ),
          subtitle: _buildNodeSubtitle(
            theme,
            node,
            mode,
            isRoot,
            course.moedBPolicy,
          ),
          trailing: trailing,
        ),
      ),
    );
  }

  Future<void> _showTargetDialog() async {
    final controller = TextEditingController(
      text: _targetGradePercent?.toStringAsFixed(2) ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('הגדרת ציון יעד'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'ציון יעד בקורס (למשל 90)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _targetGradePercent = null);
              Navigator.pop(ctx);
            },
            child: const Text('נקה יעד'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              if (v == null) {
                return;
              }
              setState(() => _targetGradePercent = v);
              Navigator.pop(ctx);
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }
}

class _FinalGradeOverrideCard extends StatefulWidget {
  const _FinalGradeOverrideCard({
    required this.course,
    required this.busy,
    required this.onSave,
  });

  final Course course;
  final bool busy;
  final Future<void> Function(double? value) onSave;

  @override
  State<_FinalGradeOverrideCard> createState() => _FinalGradeOverrideCardState();
}

class _FinalGradeOverrideCardState extends State<_FinalGradeOverrideCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.course.finalGradeOverride == null
          ? ''
          : widget.course.finalGradeOverride!.toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(covariant _FinalGradeOverrideCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course.finalGradeOverride != widget.course.finalGradeOverride &&
        oldWidget.course.id == widget.course.id) {
      _controller.text = widget.course.finalGradeOverride == null
          ? ''
          : widget.course.finalGradeOverride!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) {
      await widget.onSave(null);
      return;
    }
    final v = double.tryParse(raw);
    if (v == null || v < 0 || v > 100) {
      return;
    }
    await widget.onSave(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ציון סופי בלבד',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'הזן ציון סופי בין 0 ל־100 (למשל לשנים קודמות). השדה נשמר כ-finalGradeOverride ואינו משנה את מבנה העץ.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !widget.busy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'ציון סופי (0–100)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.busy ? null : () => widget.onSave(null),
                    child: const Text('נקה ציון'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.busy ? null : _submit,
                    child: const Text('שמור'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// תווית לשבב משקל: אחוז מנורמל מההורה (או 1/n כשההורה בשקלות שווה).
String _incomingWeightChipLabel(_TreeRowItem item) {
  final w = item.incomingWeight!;
  if (item.parentEqualWeight) {
    final n = item.parentDirectChildCount;
    if (n != null && n > 0) {
      final part = 100.0 / n;
      return 'חלק מההורה: ${part.toStringAsFixed(2)}% (1/$n)';
    }
    return 'חלק מההורה: שווה';
  }
  final sum = item.siblingWeightSum;
  if (sum == null || sum <= 0) {
    return 'משקל: ${_fmtWeight(w)}';
  }
  final pct = w / sum * 100;
  return 'חלק מההורה: ${pct.toStringAsFixed(2)}%';
}

Widget? _buildNodeSubtitle(
  ThemeData theme,
  GradeNode node,
  CalculationMode mode,
  bool isRoot,
  MoedBPolicy moedBPolicy,
) {
  switch (node) {
    case GradeLeaf(
      :final score,
      :final maxScore,
      :final bonusPoints,
      :final moedBScore,
      :final isMoedBActive,
    ):
      final bonusText = bonusPoints == 0
          ? null
          : 'בונוס: ${bonusPoints.toStringAsFixed(2)}';
      if (!isMoedBActive || moedBScore == null) {
        return Text(
          'ציון: ${score?.toString() ?? '—'} / $maxScore'
          '${bonusText != null ? ' | $bonusText' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _leafGradeColor(theme, score, maxScore),
          ),
        );
      }
      final useMoedB = switch (moedBPolicy) {
        MoedBPolicy.moedB => true,
        MoedBPolicy.higher => score == null ? true : moedBScore > score,
      };
      TextStyle scoreStyle(bool selected) => (theme.textTheme.bodySmall ??
              const TextStyle())
          .copyWith(
            decoration: selected ? null : TextDecoration.lineThrough,
            color: selected
                ? _leafGradeColor(theme, selected ? moedBScore : score, maxScore)
                : theme.colorScheme.outline,
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('מועד א: ${score?.toString() ?? '—'}', style: scoreStyle(!useMoedB)),
          Text('מועד ב: ${moedBScore.toString()}', style: scoreStyle(useMoedB)),
          if (bonusText != null)
            Text(
              bonusText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      );
    case GradeBranch(:final children):
      final small = theme.textTheme.bodySmall;
      final emptyHint = Text(
        'ריק — הוסף ענף או מטלה',
        style: small?.copyWith(
          color: isRoot ? Colors.white70 : theme.colorScheme.outline,
        ),
      );
      if (isRoot) {
        return children.isEmpty
            ? emptyHint
            : Text(
                '${children.length} רכיבים',
                style: small?.copyWith(color: Colors.white70),
              );
      }
      final cum = formatGradePercent(
        computeNormalizedGrade(
          node,
          mode,
          moedBPolicy: moedBPolicy,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ציון מצטבר: $cum',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          if (children.isEmpty)
            emptyHint
          else
            Text(
              '${children.length} רכיבים',
              style: small?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      );
  }
}

String _fmtWeight(double w) {
  if ((w - w.round()).abs() < 1e-9) {
    return w.toInt().toString();
  }
  return w.toStringAsFixed(2);
}

Color _leafGradeColor(ThemeData theme, double? score, double maxScore) {
  if (score == null) {
    return theme.colorScheme.onSurface;
  }
  final pct = score / maxScore * 100;
  if (pct >= 90) {
    return Colors.teal.shade500;
  }
  if (pct >= 75) {
    return Colors.amber.shade800;
  }
  if (pct >= 60) {
    return Colors.orange.shade700;
  }
  return theme.colorScheme.error;
}

final class _LeafContribution {
  const _LeafContribution({
    required this.name,
    required this.maxScore,
    required this.bonusPoints,
    required this.coefficient,
    required this.score,
    required this.moedBScore,
    required this.isMoedBActive,
  });

  final String name;
  final double maxScore;
  final double bonusPoints;
  final double coefficient;
  final double? score;
  final double? moedBScore;
  final bool isMoedBActive;
}

final class _TargetInsight {
  const _TargetInsight(this.message);
  final String message;
}

_TargetInsight? _computeTargetInsight(Course course, double? targetPercent) {
  if (targetPercent == null) {
    return null;
  }
  if (course.fastGrading && course.finalGradeOverride != null) {
    final currentNorm =
        computeCourseNormalizedGrade(course, CalculationMode.proportional) ?? 0.0;
    final targetNorm = targetPercent / 100.0;
    final gapNorm = targetNorm - currentNorm;
    if (gapNorm <= 0) {
      return _TargetInsight(
        'היעד ${targetPercent.toStringAsFixed(2)} כבר הושג (ציון נוכחי ${(currentNorm * 100).toStringAsFixed(2)}).',
      );
    }
    return _TargetInsight(
      'כדי להגיע ליעד (${targetPercent.toStringAsFixed(2)}), עליך להעלות את הציון הסופי שמילאת ב־${(gapNorm * 100).toStringAsFixed(2)} נקודות.',
    );
  }
  final leaves = <_LeafContribution>[];
  void visit(GradeNode node, double coeff) {
    switch (node) {
      case final GradeLeaf leaf:
        leaves.add(
          _LeafContribution(
            name: leaf.name,
            maxScore: leaf.maxScore,
            bonusPoints: leaf.bonusPoints,
            coefficient: coeff,
            score: leaf.score,
            moedBScore: leaf.moedBScore,
            isMoedBActive: leaf.isMoedBActive,
          ),
        );
      case GradeBranch(:final children, :final equalWeightChildren):
        if (children.isEmpty) {
          return;
        }
        if (equalWeightChildren) {
          final share = 1.0 / children.length;
          for (final wc in children) {
            visit(wc.node, coeff * share);
          }
          return;
        }
        final sumW = children.fold<double>(0.0, (s, c) => s + c.weight);
        if (sumW <= 0) {
          return;
        }
        for (final wc in children) {
          visit(wc.node, coeff * (wc.weight / sumW));
        }
    }
  }

  visit(course.rootNode, 1.0);
  if (leaves.isEmpty) {
    return const _TargetInsight('אין מטלות בקורס לחישוב יעד.');
  }

  final currentNorm =
      computeCourseNormalizedGrade(course, CalculationMode.proportional) ?? 0.0;
  final targetNorm = targetPercent / 100.0;
  final gapNorm = targetNorm - currentNorm;
  if (gapNorm <= 0) {
    return _TargetInsight(
      'היעד ${targetPercent.toStringAsFixed(2)} כבר הושג (ציון נוכחי ${(currentNorm * 100).toStringAsFixed(2)}).',
    );
  }

  _LeafContribution? critical;
  for (final leaf in leaves) {
    if (critical == null || leaf.coefficient > critical.coefficient) {
      critical = leaf;
    }
  }
  final c = critical;
  if (c == null || c.coefficient <= 0) {
    return const _TargetInsight('לא ניתן לזהות מטלה קריטית עם משקל אפקטיבי חיובי.');
  }

  // (Target - Current) / WeightOfCriticalTask, על סקלת נרמול; המרה לנקודות מטלה.
  final requiredDeltaNorm = gapNorm / c.coefficient;
  final requiredDeltaScore = requiredDeltaNorm * c.maxScore;
  final currentLeafScore = _selectedLeafScoreForPolicy(c, course.moedBPolicy) ?? 0.0;
  final requiredLeafScore = currentLeafScore + requiredDeltaScore;

  if (requiredLeafScore > c.maxScore + 1e-9) {
    return _TargetInsight(
      'גם ציון 100 במבחן לא יספיק להגיע ליעד. נדרש שיפור במטלות נוספות.',
    );
  }

  final deltaText = requiredDeltaScore <= 0 ? 0.0 : requiredDeltaScore;
  return _TargetInsight(
    'כדי להגיע ליעד (${targetPercent.toStringAsFixed(2)}), עליך לשפר את '
    '${c.name} ב-${deltaText.toStringAsFixed(2)} נקודות '
    '(כלומר לקבל לפחות ${requiredLeafScore.toStringAsFixed(2)}).',
  );
}

double? _selectedLeafScoreForPolicy(_LeafContribution leaf, MoedBPolicy policy) {
  if (!leaf.isMoedBActive || leaf.moedBScore == null) {
    return leaf.score;
  }
  return switch (policy) {
    MoedBPolicy.moedB => leaf.moedBScore,
    MoedBPolicy.higher => leaf.score == null
        ? leaf.moedBScore
        : (leaf.score! >= leaf.moedBScore! ? leaf.score : leaf.moedBScore),
  };
}
