import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens for the app.
///
/// Flat surfaces, no gradients or heavy shadows, a fresh green primary with
/// an amber accent for calls to action. Light and dark are tuned separately
/// so contrast holds in both.
abstract final class AppColors {
  static const primary = Color(0xFF059669);
  static const primaryDark = Color(0xFF34D399);
  static const onPrimary = Color(0xFFFFFFFF);
  static const accent = Color(0xFFD97706);
  static const accentDark = Color(0xFFFBBF24);
  static const destructive = Color(0xFFDC2626);

  static const lightBackground = Color(0xFFF8FAF9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE1F2ED);
  static const lightMuted = Color(0xFF64748B);

  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkBorder = Color(0xFF334155);
  static const darkMuted = Color(0xFF94A3B8);
}

/// 4pt spacing scale. Use these instead of ad-hoc numbers.
abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class Corners {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

/// Shared motion timings so transitions share one rhythm.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 220);
  static const enter = Duration(milliseconds: 300);
  static const exit = Duration(milliseconds: 180);
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: isDark ? AppColors.primaryDark : AppColors.primary,
    onPrimary: isDark ? const Color(0xFF052E22) : AppColors.onPrimary,
    primaryContainer: isDark
        ? const Color(0xFF064E3B)
        : const Color(0xFFD1FAE5),
    onPrimaryContainer: isDark
        ? AppColors.primaryDark
        : const Color(0xFF065F46),
    secondary: isDark ? AppColors.accentDark : AppColors.accent,
    onSecondary: isDark ? const Color(0xFF451A03) : Colors.white,
    secondaryContainer: isDark
        ? const Color(0xFF78350F)
        : const Color(0xFFFEF3C7),
    onSecondaryContainer: isDark
        ? AppColors.accentDark
        : const Color(0xFF92400E),
    tertiary: isDark ? AppColors.primaryDark : AppColors.primary,
    onTertiary: isDark ? const Color(0xFF052E22) : AppColors.onPrimary,
    error: AppColors.destructive,
    onError: Colors.white,
    errorContainer: isDark
        ? const Color(0xFF7F1D1D)
        : const Color(0xFFFEE2E2),
    onErrorContainer: isDark
        ? const Color(0xFFFECACA)
        : const Color(0xFF991B1B),
    surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    onSurface: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
    onSurfaceVariant: isDark ? AppColors.darkMuted : AppColors.lightMuted,
    outline: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
    outlineVariant: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    surfaceContainerLowest: isDark
        ? AppColors.darkBackground
        : AppColors.lightSurface,
    surfaceContainerLow: isDark
        ? const Color(0xFF172033)
        : const Color(0xFFFCFDFC),
    surfaceContainer: isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF4F7F6),
    surfaceContainerHigh: isDark
        ? const Color(0xFF273449)
        : const Color(0xFFEFF5F2),
    surfaceContainerHighest: isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE8F0EC),
    inverseSurface: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
    onInverseSurface: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
    inversePrimary: isDark ? AppColors.primary : AppColors.primaryDark,
    scrim: Colors.black54,
  );

  final textTheme = Typography.material2021(
    platform: TargetPlatform.iOS,
  ).black.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),

    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.md),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.md),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.sm),
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      extendedTextStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.lg),
      ),
    ),

    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      labelStyle: textTheme.labelLarge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.pill),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.lg)),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.lg),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.sm),
      ),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.md),
      ),
    ),

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
