/// Web pages the app links to. All are public pages of the open-source
/// project; nothing about the user is added to them.
abstract final class AppLinks {
  /// The project's repository, with the source code.
  static final Uri source = Uri.parse(
    'https://github.com/Bichoumac/Clean-Gallery',
  );

  /// The privacy policy, in English and French (`PRIVACY.md` in the
  /// repository, also given to the stores).
  static final Uri privacyPolicy = Uri.parse(
    'https://github.com/Bichoumac/Clean-Gallery/blob/main/PRIVACY.md',
  );

  /// Where to report a problem or ask for a feature.
  static final Uri issues = Uri.parse(
    'https://github.com/Bichoumac/Clean-Gallery/issues',
  );

  /// The full text of the app's license, GNU GPL v3.
  static final Uri license = Uri.parse(
    'https://github.com/Bichoumac/Clean-Gallery/blob/main/LICENSE',
  );

  /// OpenStreetMap's copyright page, for the map's data and tiles.
  static final Uri openStreetMapCopyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );
}
