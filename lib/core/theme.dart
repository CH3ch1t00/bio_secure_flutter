import 'package:flutter/material.dart';

/// Paleta BioSecure tomada de la app original de Android (ui/theme/Color.kt).
class BioColors {
  static const greenDark = Color(0xFF0D3B35);
  static const teal = Color(0xFF00B4A6);
  static const background = Color(0xFFF5F7FA);
  static const greenMedium = Color(0xFF1A5C52);
  static const tealDark = Color(0xFF00736B);
  static const tealLight = Color(0xFF4ECDC4);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const errorRed = Color(0xFFE53E3E);
  static const successGreen = Color(0xFF38A169);
  static const warnOrange = Color(0xFFED8936);
}

ThemeData buildLightTheme() => _base(
      const ColorScheme(
        brightness: Brightness.light,
        primary: BioColors.greenDark,
        onPrimary: Colors.white,
        primaryContainer: BioColors.greenMedium,
        onPrimaryContainer: Colors.white,
        secondary: BioColors.tealDark,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFB2EBE8),
        onSecondaryContainer: BioColors.greenDark,
        tertiary: BioColors.tealDark,
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFD0F5F3),
        onTertiaryContainer: BioColors.greenDark,
        error: BioColors.errorRed,
        onError: Colors.white,
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: Colors.white,
        onSurface: BioColors.textPrimary,
        surfaceContainerHighest: Color(0xFFEEF1F5),
        onSurfaceVariant: BioColors.textSecondary,
        outline: BioColors.teal,
        outlineVariant: Color(0xFFE0E0E0),
        inverseSurface: BioColors.textPrimary,
        onInverseSurface: Colors.white,
        shadow: Color(0x33000000),
        scrim: Colors.black,
      ),
      Brightness.light,
    );

ThemeData buildDarkTheme() => _base(
      const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF1ED9C5),
        onPrimary: Color(0xFF00312C),
        primaryContainer: Color(0xFF0D3B35),
        onPrimaryContainer: Color(0xFFB8FFF0),
        secondary: Color(0xFF1ED9C5),
        onSecondary: Color(0xFF00312C),
        secondaryContainer: Color(0xFF004F47),
        onSecondaryContainer: Color(0xFFB8FFF0),
        tertiary: Color(0xFF4ECDC4),
        onTertiary: Color(0xFF00312C),
        tertiaryContainer: Color(0xFF005048),
        onTertiaryContainer: Color(0xFFB8FFF0),
        error: Color(0xFFCF6679),
        onError: Color(0xFF370B1E),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: Color(0xFF1A2420),
        onSurface: Colors.white,
        surfaceContainerHighest: Color(0xFF2A3530),
        onSurfaceVariant: Color(0xB3FFFFFF),
        outline: Color(0xFF8A9590),
        outlineVariant: Color(0xFF3A4540),
        inverseSurface: Color(0xFFE3E3E1),
        onInverseSurface: Color(0xFF101512),
        shadow: Colors.black,
        scrim: Colors.black,
      ),
      Brightness.dark,
    );

ThemeData _base(ColorScheme scheme, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF101512) : BioColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: scheme.onPrimary),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? scheme.surfaceContainerHighest : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outline),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      elevation: 3,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.onSurface),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
  );
}
