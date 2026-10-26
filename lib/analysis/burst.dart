/// Burst sequences recognized from file names.
///
/// Phones save each shot of a burst as its own file, with a shared part in
/// the name. See `docs/analysis-engine.md#bursts`.
library;

/// Patterns whose first group is the part shared by every shot of a burst:
///
/// - Google Camera: `IMG_20240315_142233_BURST001.jpg`,
///   `IMG_20240315_142233_BURST002_COVER.jpg`;
/// - older Google Camera: `00000IMG_00000_BURST20190101123456789_COVER.jpg`;
/// - Samsung Camera: `20240315_142233_001.jpg`, `20240315_142233_002.jpg`.
final _patterns = [
  RegExp(r'^(.*\d{8}_\d{6})_BURST\d+(?:_COVER)?\.\w+$', caseSensitive: false),
  RegExp(r'_BURST(\d{14,17})(?:_COVER)?\.\w+$', caseSensitive: false),
  RegExp(r'^(\d{8}_\d{6})_\d{3}\.\w+$'),
];

/// Burst identifier of the file [fileName] in [folder], or `null` if the
/// name is not a burst shot.
///
/// The folder is part of the identifier, so shots are grouped only with
/// the shots saved next to them.
String? burstIdOf(String fileName, {required String folder}) {
  for (final pattern in _patterns) {
    final match = pattern.firstMatch(fileName);
    if (match != null) return '$folder|${match[1]}';
  }
  return null;
}
