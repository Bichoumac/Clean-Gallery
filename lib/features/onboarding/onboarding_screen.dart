import 'package:clean_gallery/features/onboarding/onboarding_controller.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// First-launch flow: privacy promise, media access, optional media management.
///
/// Shown before the main shell. Completing it sets the `onboarding_completed`
/// setting and the router moves to the Photos tab.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the onboarding screen.
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 3;

  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    await ref.read(onboardingCompletedProvider.notifier).markCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final isLast = state.page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: isLast ? null : _finish,
                child: Text(l10n.onboardingSkip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: controller.goToPage,
                children: [
                  _IntroPage(
                    icon: Icons.shield_outlined,
                    headline: l10n.onboardingPrivacyHeadline,
                    body: l10n.onboardingPrivacyBody,
                  ),
                  _AccessPage(
                    access: state.mediaAccess,
                    isRequesting: state.isRequesting,
                  ),
                  _IntroPage(
                    icon: Icons.cleaning_services_outlined,
                    headline: l10n.onboardingManageHeadline,
                    body: l10n.onboardingManageBody,
                    action: OutlinedButton(
                      onPressed: controller.openMediaManagementSettings,
                      child: Text(l10n.onboardingAllowManage),
                    ),
                  ),
                ],
              ),
            ),
            _PageDots(current: state.page, count: _pageCount),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLast ? _finish : () => _goTo(state.page + 1),
                  child: Text(
                    isLast ? l10n.onboardingStart : l10n.onboardingNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A page with an illustration, a headline, a body text and an optional action.
class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.icon,
    required this.headline,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String headline;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 72,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

/// The media access page. Its action changes with the result of the request.
class _AccessPage extends ConsumerWidget {
  const _AccessPage({required this.access, required this.isRequesting});

  final MediaAccess? access;
  final bool isRequesting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(onboardingControllerProvider.notifier);

    final (headline, body, action) = switch (access) {
      null => (
        l10n.onboardingAccessHeadline,
        l10n.onboardingAccessBody,
        FilledButton(
          onPressed: isRequesting ? null : controller.requestMediaAccess,
          child: Text(l10n.onboardingGrantAccess),
        ),
      ),
      MediaAccess.granted => (
        l10n.onboardingAccessHeadline,
        l10n.onboardingAccessBody,
        null,
      ),
      MediaAccess.limited => (
        l10n.onboardingLimitedHeadline,
        l10n.onboardingLimitedBody,
        OutlinedButton(
          onPressed: controller.openAppSettings,
          child: Text(l10n.onboardingGrantAll),
        ),
      ),
      MediaAccess.denied => (
        l10n.onboardingAccessHeadline,
        l10n.onboardingPermissionDenied,
        OutlinedButton(
          onPressed: controller.openAppSettings,
          child: Text(l10n.onboardingOpenSettings),
        ),
      ),
    };

    return _IntroPage(
      icon: Icons.photo_library_outlined,
      headline: headline,
      body: body,
      action: action,
    );
  }
}

/// Row of dots showing the current onboarding page.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? colors.primary : colors.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
