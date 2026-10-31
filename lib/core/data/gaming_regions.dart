class GamingRegions {
  static const values = [
    'Asia',
    'Europe',
    'North America',
    'South America',
    'Africa',
    'Oceania',
  ];

  /// Profiles use display names; parties store snake_case region identifiers.
  static String? idFor(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll(
      RegExp(r'[ _-]+'),
      '_',
    );
    for (final label in values) {
      final id = label.toLowerCase().replaceAll(' ', '_');
      if (normalized == id) return id;
    }
    return null;
  }
}
