enum DegreeTemplateStatus {
  draft,
  published,
  archived,
}

enum TemplateImportMode {
  merge,
  replace,
}

final class DegreeTemplate {
  const DegreeTemplate({
    required this.id,
    required this.degreeName,
    required this.institutionName,
    required this.cohortLabel,
    required this.degreeCreditsTarget,
    required this.status,
    required this.version,
    required this.createdByUid,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String degreeName;
  final String institutionName;
  final String cohortLabel;
  final double degreeCreditsTarget;
  final DegreeTemplateStatus status;
  final int version;
  final String createdByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => '$degreeName - $institutionName - $cohortLabel';

  DegreeTemplate copyWith({
    String? id,
    String? degreeName,
    String? institutionName,
    String? cohortLabel,
    double? degreeCreditsTarget,
    DegreeTemplateStatus? status,
    int? version,
    String? createdByUid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DegreeTemplate(
      id: id ?? this.id,
      degreeName: degreeName ?? this.degreeName,
      institutionName: institutionName ?? this.institutionName,
      cohortLabel: cohortLabel ?? this.cohortLabel,
      degreeCreditsTarget: degreeCreditsTarget ?? this.degreeCreditsTarget,
      status: status ?? this.status,
      version: version ?? this.version,
      createdByUid: createdByUid ?? this.createdByUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
