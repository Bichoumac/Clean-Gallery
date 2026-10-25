import 'package:flutter/material.dart';

/// Brand colors of Clean Gallery. See `docs/design.md`.
///
/// One accent (lime) on neutral "ink" and "paper" surfaces. Use the
/// [ColorScheme] from the theme in widgets; reference these constants only
/// when building the theme.
abstract final class AppColors {
  /// Signature accent: active tab, primary buttons, highlights.
  static const lime = Color(0xFFCFF25B);

  /// Near-black used for dark surfaces and text on [lime].
  static const ink = Color(0xFF121316);

  /// Warm off-white used for light surfaces.
  static const paper = Color(0xFFF7F6F3);

  /// Accent for text and icons in light mode, where [lime] lacks contrast.
  static const olive = Color(0xFF3F5A00);
}

/// Theme of Clean Gallery: neutral surfaces, a single lime accent, the
/// Manrope typeface, large rounded shapes and no shadows.
abstract final class AppTheme {
  /// Corner radius shared by cards, sheets and dialogs.
  static const cornerRadius = 24.0;

  /// Light theme.
  static ThemeData light() => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.olive,
      onPrimary: Colors.white,
      primaryContainer: AppColors.lime,
      onPrimaryContainer: AppColors.ink,
      secondary: Color(0xFF5E616A),
      onSecondary: Colors.white,
      error: Color(0xFFC4314B),
      onError: Colors.white,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      onSurfaceVariant: Color(0xFF5E616A),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF2F1ED),
      surfaceContainer: Color(0xFFEDEBE6),
      surfaceContainerHigh: Color(0xFFE7E5DF),
      surfaceContainerHighest: Color(0xFFE1DED8),
      outline: Color(0xFFC9C6BE),
      outlineVariant: Color(0xFFDEDBD3),
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.paper,
    ),
  );

  /// Dark theme.
  static ThemeData dark() => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.lime,
      onPrimary: AppColors.ink,
      primaryContainer: AppColors.lime,
      onPrimaryContainer: AppColors.ink,
      secondary: Color(0xFFA3A6AE),
      onSecondary: AppColors.ink,
      error: Color(0xFFFF6B81),
      onError: AppColors.ink,
      surface: Color(0xFF0F1012),
      onSurface: Color(0xFFF2F1EE),
      onSurfaceVariant: Color(0xFFA3A6AE),
      surfaceContainerLowest: Color(0xFF0A0B0D),
      surfaceContainerLow: Color(0xFF15161A),
      surfaceContainer: Color(0xFF1A1C20),
      surfaceContainerHigh: Color(0xFF212328),
      surfaceContainerHighest: Color(0xFF292B31),
      outline: Color(0xFF3A3D45),
      outlineVariant: Color(0xFF2A2C33),
      inverseSurface: AppColors.paper,
      onInverseSurface: AppColors.ink,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cornerRadius),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Manrope',
      textTheme: _textTheme(scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
            top: Radius.circular(cornerRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          minimumSize: const Size(48, 56),
          shape: const StadiumBorder(),
          textStyle: _weighted(const TextStyle(fontSize: 16), 700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(48, 48),
        ),
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

  /// Manrope type scale: heavy, tight display and headline styles for page
  /// titles; regular weights for reading text.
  static TextTheme _textTheme(ColorScheme scheme) {
    final base = Typography.material2021().black.apply(
      fontFamily: 'Manrope',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    TextStyle style(TextStyle? s, int weight, {double? tracking}) =>
        _weighted(s!.copyWith(letterSpacing: tracking), weight);
    return base.copyWith(
      displayLarge: style(base.displayLarge, 800, tracking: -1.5),
      displayMedium: style(base.displayMedium, 800, tracking: -1),
      displaySmall: style(base.displaySmall, 800, tracking: -0.8),
      headlineLarge: style(base.headlineLarge, 800, tracking: -0.8),
      headlineMedium: style(base.headlineMedium, 800, tracking: -0.6),
      headlineSmall: style(base.headlineSmall, 700, tracking: -0.4),
      titleLarge: style(base.titleLarge, 700, tracking: -0.2),
      titleMedium: style(base.titleMedium, 700),
      titleSmall: style(base.titleSmall, 600),
      bodyLarge: style(base.bodyLarge, 400),
      bodyMedium: style(base.bodyMedium, 400),
      bodySmall: style(base.bodySmall, 500),
      labelLarge: style(base.labelLarge, 700),
      labelMedium: style(base.labelMedium, 600),
      labelSmall: style(base.labelSmall, 600),
    );
  }

  /// Applies [weight] both as a [FontWeight] and as the variable font's
  /// `wght` axis, so the bundled variable Manrope renders the right weight.
  static TextStyle _weighted(TextStyle style, int weight) => style.copyWith(
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );
}
