/// Screenshots recognized from where they are saved, their name and their
/// size. See `docs/analysis-engine.md#screenshots`.
library;

/// Screenshot names of Android, Samsung and Xiaomi phones:
/// `Screenshot_20240315-142233_Chrome.jpg`, `Screenshot_2024-03-15.png`,
/// `Screenshot 2024-03-15 at 14.22.33.png` (copied from a computer).
final _name = RegExp(r'^screen[\s_-]?shot', caseSensitive: false);

/// Whether a photo is a screenshot:
///
/// 1. it is in a folder named `Screenshots` (`DCIM/Screenshots/`,
///    `Pictures/Screenshots/`), or
/// 2. its file name starts with "Screenshot", or
/// 3. it is a PNG exactly the size of the device [screen], in either
///    orientation: screenshots saved by apps, which use neither.
///
/// [screen] is the display size in physical pixels, or `null` when unknown.
bool isScreenshot({
  required String relativePath,
  required String fileName,
  required String mimeType,
  required int width,
  required int height,
  ({int width, int height})? screen,
}) {
  final folders = relativePath.toLowerCase().split('/');
  if (folders.contains('screenshots')) return true;
  if (_name.hasMatch(fileName)) return true;
  if (screen == null || mimeType != 'image/png') return false;
  return (width == screen.width && height == screen.height) ||
      (width == screen.height && height == screen.width);
}
