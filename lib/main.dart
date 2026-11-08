import 'package:clean_gallery/app.dart';
import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/core/theme/font_licenses.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entry point.
///
/// Reads the onboarding flag and the user settings before the first frame,
/// so the router opens the right screen and the theme and language are right
/// immediately, without a loading state.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  // Room for the thumbnails of several screens of grid (about 260 KB each
  // decoded), so scrolling back does not reload them.
  PaintingBinding.instance.imageCache
    ..maximumSize = 2000
    ..maximumSizeBytes = 200 << 20;

  final database = AppDatabase.open();
  final settings = SettingsRepository(database);
  final onboardingCompleted = await settings.readBool(
    SettingKeys.onboardingCompleted,
  );
  final appSettings = await settings.loadAppSettings();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        initialOnboardingCompletedProvider.overrideWithValue(
          onboardingCompleted,
        ),
        initialAppSettingsProvider.overrideWithValue(appSettings),
      ],
      child: const CleanGalleryApp(),
    ),
  );
}
