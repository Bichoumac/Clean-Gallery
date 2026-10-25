import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_controller.freezed.dart';
part 'onboarding_controller.g.dart';

/// Immutable state of the onboarding flow.
@freezed
abstract class OnboardingState with _$OnboardingState {
  /// Creates the state. Defaults to the first page with nothing requested.
  const factory OnboardingState({
    /// Index of the visible page, from 0 to 2.
    @Default(0) int page,

    /// Result of the last media access request, `null` before any request.
    MediaAccess? mediaAccess,

    /// Whether a permission request is in progress.
    @Default(false) bool isRequesting,
  }) = _OnboardingState;
}

/// Drives the onboarding screen: page navigation and permission requests.
///
/// The screen only renders [OnboardingState] and forwards user actions here,
/// so the flow can be tested without any widget.
@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingState build() => const OnboardingState();

  /// Records the page the user is looking at.
  void goToPage(int page) {
    state = state.copyWith(page: page);
  }

  /// Asks for media access, then asks for GPS access if media was granted.
  ///
  /// GPS is only requested when some media access was given, because EXIF
  /// location is only useful for the photos the app can see.
  Future<void> requestMediaAccess() async {
    state = state.copyWith(isRequesting: true);
    final permissions = ref.read(permissionServiceProvider);
    final access = await permissions.requestMediaAccess();
    if (access != MediaAccess.denied) {
      await permissions.requestLocationAccess();
    }
    state = state.copyWith(isRequesting: false, mediaAccess: access);
  }

  /// Opens this app's system settings, to widen a partial or denied grant.
  Future<void> openAppSettings() {
    return ref.read(permissionServiceProvider).openAppSettings();
  }

  /// Opens the optional "Media management" settings screen.
  Future<void> openMediaManagementSettings() {
    return ref.read(platformBridgeProvider).openMediaManagementSettings();
  }
}

/// Whether onboarding is complete. Persisted in the `settings` table.
///
/// The router redirects to onboarding while this is `false`.
@Riverpod(keepAlive: true)
class OnboardingCompleted extends _$OnboardingCompleted {
  @override
  bool build() => ref.watch(initialOnboardingCompletedProvider);

  /// Saves the completion flag and updates the router's view of it.
  Future<void> markCompleted() async {
    await ref
        .read(settingsRepositoryProvider)
        .writeBool(SettingKeys.onboardingCompleted, value: true);
    state = true;
  }
}
