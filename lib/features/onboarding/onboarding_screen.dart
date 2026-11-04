import 'package:clean_gallery/core/brand/petal_mark.dart';
import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/features/onboarding/onboarding_controller.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:clean_gallery/platform/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (AppMotion.reduced(context)) {
      _pageController.jumpToPage(page);
      return;
    }
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: AppMotion.curve,
    );
  }

  Future<void> _finish() async {
    await ref.read(onboardingCompletedProvider.notifier).markCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final isLast = state.page == _pageCount - 1;
    // The first page is a poster: ink on sun, whatever the theme.
    final poster = state.page == 0;
    final foreground = poster ? AppColors.ink : colors.onSurface;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: poster || colors.brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        body: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.standard),
          curve: AppMotion.curve,
          color: poster ? AppColors.sun : colors.surface,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    PageView(
                      controller: _pageController,
                      onPageChanged: controller.goToPage,
                      children: [
                        _IntroPage(
                          poster: true,
                          headline: l10n.onboardingPrivacyHeadline,
                          body: l10n.onboardingPrivacyBody,
                        ),
                        _AccessPage(
                          access: state.mediaAccess,
                          isRequesting: state.isRequesting,
                        ),
                        _IntroPage(
                          headline: l10n.onboardingManageHeadline,
                          body: l10n.onboardingManageBody,
                          action: OutlinedButton(
                            onPressed: controller.openMediaManagementSettings,
                            child: Text(l10n.onboardingAllowManage),
                          ),
                        ),
                      ],
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, top: 4),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: foreground,
                          ),
                          onPressed: isLast ? null : _finish,
                          child: Text(l10n.onboardingSkip),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _PageDots(
                    current: state.page,
                    count: _pageCount,
                    color: foreground,
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: poster
                          ? FilledButton.styleFrom(
                              backgroundColor: AppColors.ink,
                              foregroundColor: AppColors.sun,
                            )
                          : null,
                      onPressed: isLast ? _finish : () => _goTo(state.page + 1),
                      child: Text(
                        isLast ? l10n.onboardingStart : l10n.onboardingNext,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A page: the mark bleeding off the top right, then a large headline, a body
/// text and an optional action at the bottom.
class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.headline,
    required this.body,
    this.poster = false,
    this.action,
  });

  final String headline;
  final String body;

  /// Whether this is the first page: ink on sun, its mark appearing petal by
  /// petal.
  final bool poster;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = poster ? AppColors.ink : theme.colorScheme.onSurface;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final markSize = width * 1.43;
        // At the largest text sizes the text covers the page: the mark would
        // only make it harder to read.
        final showMark = MediaQuery.textScalerOf(context).scale(1) <= 1.5;
        return Stack(
          children: [
            if (showMark)
              Positioned(
                top: -width * 0.12,
                right: -width * 0.22,
                child: poster
                    ? BloomingMark(
                        size: markSize,
                        colors: List.generate(
                          petalCount,
                          (i) => i == litPetal
                              ? AppColors.ink
                              : AppColors.petalOnSun,
                        ),
                      )
                    : EmptyMark(size: markSize),
              ),
            // Scrolls at large text sizes rather than being clipped.
            Align(
              alignment: Alignment.bottomLeft,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: foreground,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        body,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: foreground,
                          fontWeight: poster ? FontWeight.w600 : null,
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(height: 20),
                        action!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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

    return _IntroPage(headline: headline, body: body, action: action);
  }
}

/// Row of dots showing the current onboarding page.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.current,
    required this.count,
    required this.color,
  });

  final int current;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.standard),
            margin: const EdgeInsets.only(right: 8),
            width: i == current ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? color : color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
