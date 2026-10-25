import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/features/onboarding/onboarding_controller.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakePermissionService permissions;
  late FakePlatformBridge bridge;
  late ProviderContainer container;

  setUp(() {
    permissions = FakePermissionService();
    bridge = FakePlatformBridge();
    final db = inMemoryDatabase();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        permissionServiceProvider.overrideWithValue(permissions),
        platformBridgeProvider.overrideWithValue(bridge),
        initialOnboardingCompletedProvider.overrideWithValue(false),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  OnboardingController controller() {
    // Keep the auto-dispose provider alive for the duration of the test.
    container.listen(onboardingControllerProvider, (_, _) {});
    return container.read(onboardingControllerProvider.notifier);
  }

  test('starts on the first page with nothing requested', () {
    controller();
    final state = container.read(onboardingControllerProvider);
    expect(state.page, 0);
    expect(state.mediaAccess, isNull);
    expect(state.isRequesting, isFalse);
  });

  test('granted media access also requests GPS access', () async {
    await controller().requestMediaAccess();
    final state = container.read(onboardingControllerProvider);
    expect(state.mediaAccess, MediaAccess.granted);
    expect(state.isRequesting, isFalse);
    expect(permissions.locationRequests, 1);
  });

  test('limited access is reported and still requests GPS', () async {
    permissions.result = MediaAccess.limited;
    await controller().requestMediaAccess();
    expect(
      container.read(onboardingControllerProvider).mediaAccess,
      MediaAccess.limited,
    );
    expect(permissions.locationRequests, 1);
  });

  test('denied media access does not request GPS', () async {
    permissions.result = MediaAccess.denied;
    await controller().requestMediaAccess();
    expect(
      container.read(onboardingControllerProvider).mediaAccess,
      MediaAccess.denied,
    );
    expect(permissions.locationRequests, 0);
  });

  test('opens the media management settings through the bridge', () async {
    await controller().openMediaManagementSettings();
    expect(bridge.mediaManagementOpened, 1);
  });

  test('completing onboarding persists the flag', () async {
    expect(container.read(onboardingCompletedProvider), isFalse);
    await container.read(onboardingCompletedProvider.notifier).markCompleted();
    expect(container.read(onboardingCompletedProvider), isTrue);
    final stored = await container
        .read(settingsRepositoryProvider)
        .readBool(SettingKeys.onboardingCompleted);
    expect(stored, isTrue);
  });
}
