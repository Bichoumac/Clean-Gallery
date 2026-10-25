import 'package:clean_gallery/app.dart';
import 'package:clean_gallery/core/database/app_database.dart';
import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entry point.
///
/// Reads the onboarding flag before the first frame, so the router can open
/// the right screen immediately without a loading state.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase.open();
  final onboardingCompleted = await SettingsRepository(database)
      .readBool(SettingKeys.onboardingCompleted);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        initialOnboardingCompletedProvider.overrideWithValue(
          onboardingCompleted,
        ),
      ],
      child: const CleanGalleryApp(),
    ),
  );
}
