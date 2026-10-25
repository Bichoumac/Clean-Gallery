import 'package:flutter/material.dart';

/// Material 3 theme for Clean Gallery.
///
/// Colors come from a [ColorScheme]: either the dynamic scheme from the
/// wallpaper (Material You) or a seed-based fallback. Shapes are rounded
/// throughout, as the design guidelines require.
abstract final class AppTheme {
  /// Seed color used when dynamic colors are unavailable (Android below 12).
  static const seed = Color(0xFF3F6B5A);

  /// Corner radius shared by cards, sheets and dialogs.
  static const cornerRadius = 20.0;

  /// Builds the theme for [scheme], light or dark.
  static ThemeData fromScheme(ColorScheme scheme) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cornerRadius),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      cardTheme: CardThemeData(shape: shape, clipBehavior: Clip.antiAlias),
      dialogTheme: DialogThemeData(shape: shape),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(cornerRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Fallback light theme from [seed].
  static ThemeData light() => fromScheme(ColorScheme.fromSeed(seedColor: seed));

  /// Fallback dark theme from [seed].
  static ThemeData dark() => fromScheme(
    ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
  );
}
