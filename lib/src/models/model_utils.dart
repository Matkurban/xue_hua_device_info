/// Returns the trimmed [value] when non-empty, or `null` otherwise.
String? nonEmptyOrNull(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
