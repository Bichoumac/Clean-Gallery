import 'package:flutter/material.dart';

/// Brand colors of Clean Gallery, the Éclat Soleil identity. See
/// `docs/design.md`.
///
/// One accent (sun yellow) on warm "ink" and "cream" surfaces. Use the
/// [ColorScheme] from the theme in widgets; reference these constants only
/// when building the theme, and for the logo tones that have no place in a
/// scheme.
abstract final class AppColors {
  /// Signature accent: active tab, primary buttons, highlights.
  static const sun = Color(0xFFFFCB47);

  /// Warm near-black used for dark surfaces and text on [sun].
  static const ink = Color(0xFF14110C);

  /// Warm off-white used for light surfaces.
  static const cream = Color(0xFFFBF8F1);

  /// Accent for text and icons in light mode, where [sun] lacks contrast.
  static const amber = Color(0xFF8A5A00);

  /// Unlit petals of the large mark on [sun] (hero card, onboarding).
  static const petalOnSun = Color(0xFFE8AC33);

  /// Unlit petals of the logo on [ink], outside the app icon.
  static const petalOnInk = Color(0xFF857C6E);
}

/// Theme of Clean Gallery: warm surfaces, neutral photo grids, a single sun
/// accent, Bricolage Grotesque titles over Manrope text, large rounded shapes
/// and no shadows.
abstract final class AppTheme {
  /// Corner radius shared by cards, tiles and dialogs.
  static const cornerRadius = 26.0;

  /// Corner radius of bottom sheets.
  static const sheetRadius = 24.0;

  /// Typeface of titles and key numbers.
  static const displayFont = 'Bricolage Grotesque';

  /// Typeface of everything else.
  static const textFont = 'Manrope';

  /// Light theme.
  static ThemeData light() => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.amber,
      onPrimary: Colors.white,
      primaryContainer: AppColors.sun,
      onPrimaryContainer: AppColors.ink,
      secondary: Color(0xFF5F574A),
      onSecondary: Colors.white,
      error: Color(0xFFC4361F),
      onError: Colors.white,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
      onSurfaceVariant: Color(0xFF5F574A),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF6F2E8),
      surfaceContainer: Color(0xFFF0EBDF),
      surfaceContainerHigh: Color(0xFFE9E3D5),
      surfaceContainerHighest: Color(0xFFE2DBCB),
      outline: Color(0xFF8F8675),
      outlineVariant: Color(0xFFE0D9CA),
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.cream,
    ),
  );

  /// Dark theme.
  static ThemeData dark() => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.sun,
      onPrimary: AppColors.ink,
      primaryContainer: AppColors.sun,
      onPrimaryContainer: AppColors.ink,
      secondary: Color(0xFFB3AB9D),
      onSecondary: AppColors.ink,
      error: Color(0xFFFF6B5E),
      onError: AppColors.ink,
      surface: AppColors.ink,
      onSurface: Color(0xFFF6F1E7),
      onSurfaceVariant: Color(0xFFB3AB9D),
      surfaceContainerLowest: Color(0xFF0A0A0A),
      surfaceContainerLow: Color(0xFF1E1A14),
      surfaceContainer: Color(0xFF26211A),
      surfaceContainerHigh: Color(0xFF2E2820),
      surfaceContainerHighest: Color(0xFF38312A),
      outline: Color(0xFF6E6556),
      outlineVariant: Color(0xFF332D24),
      inverseSurface: AppColors.cream,
      onInverseSurface: AppColors.ink,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cornerRadius),
    );
    final textTheme = _textTheme(scheme);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: textFont,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineMedium,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: rounded.copyWith(side: BorderSide(color: scheme.outlineVariant)),
      ),
      dialogTheme: DialogThemeData(
        shape: rounded,
        backgroundColor: scheme.surfaceContainer,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(sheetRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          minimumSize: const Size(48, 56),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline),
        selectedColor: scheme.primaryContainer,
        secondarySelectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurface,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }

  /// Type scale of `docs/design.md`: Bricolage Grotesque for display and
  /// headline styles, Manrope for everything else.
  static TextTheme _textTheme(ColorScheme scheme) {
    final base = Typography.material2021().black.apply(
      fontFamily: textFont,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    TextStyle display(TextStyle? s, double size, int weight, double tracking) =>
        _display(s!.copyWith(fontSize: size, letterSpacing: tracking), weight);
    TextStyle text(TextStyle? s, double size, int weight, {double? tracking}) =>
        _weighted(s!.copyWith(fontSize: size, letterSpacing: tracking), weight);
    return base.copyWith(
      displayLarge: display(base.displayLarge, 57, 800, -2),
      displayMedium: display(base.displayMedium, 45, 800, -1.5),
      displaySmall: display(base.displaySmall, 36, 800, -1),
      headlineLarge: display(base.headlineLarge, 32, 800, -0.9),
      headlineMedium: display(base.headlineMedium, 28, 800, -0.8),
      headlineSmall: display(base.headlineSmall, 22, 700, -0.4),
      titleLarge: text(base.titleLarge, 22, 700, tracking: -0.2),
      titleMedium: text(base.titleMedium, 16, 800, tracking: 0),
      titleSmall: text(base.titleSmall, 14, 700, tracking: 0),
      bodyLarge: text(base.bodyLarge, 16, 400, tracking: 0),
      bodyMedium: text(base.bodyMedium, 14, 400, tracking: 0),
      bodySmall: text(base.bodySmall, 12, 500, tracking: 0),
      labelLarge: text(base.labelLarge, 14, 800, tracking: 0),
      labelMedium: text(base.labelMedium, 12, 700),
      labelSmall: text(base.labelSmall, 11, 700),
    );
  }

  /// A Bricolage Grotesque style: its optical size follows the font size
  /// (the axis goes from 12 to 96), which tightens large titles.
  static TextStyle _display(TextStyle style, int weight) => style.copyWith(
    fontFamily: displayFont,
    fontWeight: _fontWeight(weight),
    fontVariations: [
      FontVariation('wght', weight.toDouble()),
      FontVariation('opsz', style.fontSize!.clamp(12, 96).toDouble()),
    ],
  );

  /// Applies [weight] both as a [FontWeight] and as the variable font's
  /// `wght` axis, so the bundled variable Manrope renders the right weight.
  static TextStyle _weighted(TextStyle style, int weight) => style.copyWith(
    fontWeight: _fontWeight(weight),
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );

  static FontWeight _fontWeight(int weight) =>
      FontWeight.values[(weight ~/ 100) - 1];
}
