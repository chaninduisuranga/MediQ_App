String formatDoctorDisplayName(Object? name, {required String fallback}) {
  final value = name?.toString().trim() ?? '';
  final withoutTitles = value
      .replaceFirst(
        RegExp(r'^(?:Dr\.?\s*)+', caseSensitive: false),
        '',
      )
      .trim();
  return 'Dr. ${withoutTitles.isEmpty ? fallback : withoutTitles}';
}
