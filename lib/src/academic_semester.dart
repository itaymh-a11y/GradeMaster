/// Degree year (שנה א׳ / ב׳).
enum AcademicYear {
  a,
  b,
  c,
  d,
}

/// Academic semester within a degree year (א׳ / ב׳ / קיץ).
enum SemesterKind {
  a,
  b,
  summer,
}

extension AcademicYearLabel on AcademicYear {
  String get heLabel {
    switch (this) {
      case AcademicYear.a:
        return 'שנה א׳';
      case AcademicYear.b:
        return 'שנה ב׳';
      case AcademicYear.c:
        return 'שנה ג׳';
      case AcademicYear.d:
        return 'שנה ד׳';
    }
  }
}

extension SemesterKindLabel on SemesterKind {
  String get heLabel {
    switch (this) {
      case SemesterKind.a:
        return 'סמסטר א׳';
      case SemesterKind.b:
        return 'סמסטר ב׳';
      case SemesterKind.summer:
        return 'סמסטר קיץ';
    }
  }
}
