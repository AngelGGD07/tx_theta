import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores de marca fijos (logo, acentos). No cambian entre modo
/// claro/oscuro — son la identidad visual de BiPi en cualquier contexto.
class AppColors {
  AppColors._();

  static const amber = Color(0xFFFFCC70);
  static const deepBlue = Color(0xFF061E29);
  static const teal = Color(0xFF1D546D);
  static const tealLight = Color(0xFF5F9598);
  static const offWhite = Color(0xFFF3F4F4);
}

/// Paleta que SÍ cambia según el modo claro/oscuro. Úsala para fondo,
/// superficie y texto en vez de AppColors directamente — así cada pantalla
/// se adapta sola sin lógica repetida.
class AppPalette {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color primaryAction;
  final Color onPrimaryAction;
  final Color destructive;
  final Color warning;
  final Color success;
  final Color disabledBackground;
  final Color disabledForeground;
  final Color confrontationBackground;
  final Color confrontationBorder;
  final Color confrontationText;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.destructive,
    required this.warning,
    required this.success,
    required this.disabledBackground,
    required this.disabledForeground,
    required this.confrontationBackground,
    required this.confrontationBorder,
    required this.confrontationText,
  });

  static const light = AppPalette(
    background: Color(0xFFF3F4F4),
    surface: Colors.white,
    surfaceElevated: Color(0xFFE9F0F2),
    textPrimary: Color(0xFF061E29),
    textSecondary: Color(0xFF1D546D),
    textMuted: Color(0xFF5F7A82),
    border: Color(0xFFB8CCD0),
    primaryAction: Color(0xFFFFCC70),
    onPrimaryAction: Color(0xFF061E29),
    destructive: Color(0xFFB3261E),
    warning: Color(0xFF8A5A00),
    success: Color(0xFF1B5E20),
    disabledBackground: Color(0xFFD8DEE0),
    disabledForeground: Color(0xFF8A9BA0),
    confrontationBackground: Color(0xFFE7F0F2),
    confrontationBorder: Color(0xFF1D546D),
    confrontationText: Color(0xFF061E29),
  );

  static const dark = AppPalette(
    background: Color(0xFF061E29),
    surface: Color(0xFF0C2A38),
    surfaceElevated: Color(0xFF123746),
    textPrimary: Color(0xFFF3F4F4),
    textSecondary: Color(0xFFB8CCD0),
    textMuted: Color(0xFF7A98A0),
    border: Color(0xFF2C4A5A),
    primaryAction: Color(0xFFFFCC70),
    onPrimaryAction: Color(0xFF061E29),
    destructive: Color(0xFFFFB4AB),
    warning: Color(0xFFFFD54F),
    success: Color(0xFFA5D6A7),
    disabledBackground: Color(0xFF1A3644),
    disabledForeground: Color(0xFF5C7884),
    confrontationBackground: Color(0xFF123746),
    confrontationBorder: Color(0xFF5F9598),
    confrontationText: Color(0xFFF3F4F4),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Sistema tipográfico: Figtree es la única familia.
/// Los pesos se limitan a 400, 500, 600 y 700.
class AppTypography {
  AppTypography._();

  static TextStyle logo({required Color color, double size = 28}) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.0,
      );

  static TextStyle tagline({required Color color, double size = 14}) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: color,
      );

  static TextStyle screenTitle({required Color color, double size = 24}) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle body({required Color color, double size = 15}) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle label({required Color color, double size = 13}) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle button({required Color color, double size = 16}) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.2,
      );

  static TextStyle valueStrong({required Color color, double size = 26}) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
      );
}

/// Construye ThemeData para modo claro sin usar ColorScheme.fromSeed,
/// para evitar colores generados que rompan la paleta.
ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.light.primaryAction,
    onPrimary: AppPalette.light.onPrimaryAction,
    secondary: AppPalette.light.surfaceElevated,
    onSecondary: AppPalette.light.textPrimary,
    error: AppPalette.light.destructive,
    onError: Colors.white,
    surface: AppPalette.light.surface,
    onSurface: AppPalette.light.textPrimary,
    outline: AppPalette.light.border,
    shadow: Colors.black26,
  );

  return base.copyWith(
    textTheme: GoogleFonts.figtreeTextTheme(base.textTheme),
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppPalette.light.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppPalette.light.background,
      foregroundColor: AppPalette.light.textPrimary,
      elevation: 0,
      titleTextStyle: AppTypography.screenTitle(color: AppPalette.light.textPrimary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.deepBlue,
      contentTextStyle: AppTypography.body(color: AppPalette.light.surface),
      actionTextColor: AppColors.amber,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.light.surface,
      labelStyle: AppTypography.label(color: AppPalette.light.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppPalette.light.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppPalette.light.textPrimary, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.light.primaryAction,
        foregroundColor: AppPalette.light.onPrimaryAction,
        textStyle: AppTypography.button(color: AppPalette.light.onPrimaryAction),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.light.textPrimary,
        side: BorderSide(color: AppPalette.light.border),
        textStyle: AppTypography.button(color: AppPalette.light.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppPalette.light.primaryAction,
      foregroundColor: AppPalette.light.onPrimaryAction,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppPalette.light.surface,
      selectedColor: AppPalette.light.primaryAction,
      labelStyle: AppTypography.label(color: AppPalette.light.textPrimary),
      secondaryLabelStyle: AppTypography.label(color: AppPalette.light.onPrimaryAction),
      side: BorderSide(color: AppPalette.light.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppPalette.light.surface,
      modalBackgroundColor: AppPalette.light.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppPalette.light.surface,
      titleTextStyle: AppTypography.screenTitle(color: AppPalette.light.textPrimary),
      contentTextStyle: AppTypography.body(color: AppPalette.light.textPrimary),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppPalette.light.surface,
      headerBackgroundColor: AppPalette.light.surfaceElevated,
      headerForegroundColor: AppPalette.light.textPrimary,
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.dark.primaryAction,
    onPrimary: AppPalette.dark.onPrimaryAction,
    secondary: AppPalette.dark.surfaceElevated,
    onSecondary: AppPalette.dark.textPrimary,
    error: AppPalette.dark.destructive,
    onError: Colors.black,
    surface: AppPalette.dark.surface,
    onSurface: AppPalette.dark.textPrimary,
    outline: AppPalette.dark.border,
    shadow: Colors.black,
  );

  return base.copyWith(
    textTheme: GoogleFonts.figtreeTextTheme(base.textTheme),
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppPalette.dark.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppPalette.dark.background,
      foregroundColor: AppPalette.dark.textPrimary,
      elevation: 0,
      titleTextStyle: AppTypography.screenTitle(color: AppPalette.dark.textPrimary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.amber,
      contentTextStyle: AppTypography.body(
        color: AppColors.deepBlue,
      ),
      actionTextColor: AppColors.deepBlue,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.dark.surface,
      labelStyle: AppTypography.label(color: AppPalette.dark.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppPalette.dark.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppPalette.dark.textPrimary, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.dark.primaryAction,
        foregroundColor: AppPalette.dark.onPrimaryAction,
        textStyle: AppTypography.button(color: AppPalette.dark.onPrimaryAction),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.dark.textPrimary,
        side: BorderSide(color: AppPalette.dark.border),
        textStyle: AppTypography.button(color: AppPalette.dark.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppPalette.dark.primaryAction,
      foregroundColor: AppPalette.dark.onPrimaryAction,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppPalette.dark.surface,
      selectedColor: AppPalette.dark.primaryAction,
      labelStyle: AppTypography.label(color: AppPalette.dark.textPrimary),
      secondaryLabelStyle: AppTypography.label(color: AppPalette.dark.onPrimaryAction),
      side: BorderSide(color: AppPalette.dark.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppPalette.dark.surface,
      modalBackgroundColor: AppPalette.dark.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppPalette.dark.surface,
      titleTextStyle: AppTypography.screenTitle(color: AppPalette.dark.textPrimary),
      contentTextStyle: AppTypography.body(color: AppPalette.dark.textPrimary),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppPalette.dark.surface,
      headerBackgroundColor: AppPalette.dark.surfaceElevated,
      headerForegroundColor: AppPalette.dark.textPrimary,
    ),
  );
}