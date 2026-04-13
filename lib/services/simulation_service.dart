import 'package:flutter/foundation.dart';
import 'package:grade_master/grade_master.dart';

class SimulationService extends ChangeNotifier {
  bool _enabled = false;
  final Map<String, Course> _simulatedCourses = <String, Course>{};
  final Set<String> _deletedCourseIds = <String>{};

  bool get enabled => _enabled;
  Map<String, Course> get simulatedCourses =>
      Map<String, Course>.unmodifiable(_simulatedCourses);

  void toggle() {
    _enabled = !_enabled;
    if (!_enabled) {
      _simulatedCourses.clear();
      _deletedCourseIds.clear();
    }
    notifyListeners();
  }

  void setEnabled(bool value) {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (!_enabled) {
      _simulatedCourses.clear();
      _deletedCourseIds.clear();
    }
    notifyListeners();
  }

  Course resolveCourse(Course base) {
    if (!_enabled) {
      return base;
    }
    return _simulatedCourses[base.id] ?? base;
  }

  Course? resolveCourseOrNull(Course base) {
    if (!_enabled) {
      return base;
    }
    if (_deletedCourseIds.contains(base.id)) {
      return null;
    }
    return _simulatedCourses[base.id] ?? base;
  }

  void saveSimulatedRoot({
    required Course base,
    required GradeNode rootNode,
  }) {
    if (!_enabled) {
      return;
    }
    _simulatedCourses[base.id] = Course(
      id: base.id,
      name: base.name,
      credits: base.credits,
      rootNode: rootNode,
      isPassFail: base.isPassFail,
      academicYear: base.academicYear,
      semester: base.semester,
      finalBonus: base.finalBonus,
      moedBPolicy: base.moedBPolicy,
    );
    notifyListeners();
  }

  void saveSimulatedCourse(Course course) {
    if (!_enabled) {
      return;
    }
    _deletedCourseIds.remove(course.id);
    _simulatedCourses[course.id] = course;
    notifyListeners();
  }

  void deleteSimulatedCourse(String courseId) {
    if (!_enabled) {
      return;
    }
    _simulatedCourses.remove(courseId);
    _deletedCourseIds.add(courseId);
    notifyListeners();
  }
}
