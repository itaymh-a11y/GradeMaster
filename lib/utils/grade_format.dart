/// Display-only: normalized 0–1 → percent `0.00`–`100.00` with 2 decimals + `%`.
/// [normalized] `null` → em dash (e.g. proportional mode with no grades).
String formatGradePercent(double? normalized) {
  if (normalized == null) {
    return '—';
  }
  return '${(normalized * 100).toStringAsFixed(2)}%';
}
