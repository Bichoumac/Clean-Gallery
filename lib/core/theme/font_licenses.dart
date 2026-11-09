import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The fonts bundled in `assets/fonts/`, each with its license file.
const _fonts = {
  'Manrope': 'assets/fonts/manrope/OFL.txt',
  'Bricolage Grotesque': 'assets/fonts/bricolage_grotesque/OFL.txt',
};

/// Adds the licenses of the bundled fonts to the licenses page
/// (About → Open source libraries), next to those of the packages, which
/// Flutter adds by itself. The files are read only when the page opens.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: font, value: asset) in _fonts.entries) {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString(asset));
    }
  });
}
