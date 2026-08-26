import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores de marca fijos que no dependen del tema.
class AppColors {
  AppColors._();

  static const amber = Color(0xFFF1C376);
  static const deepBlue = Color(0xFF263229);
}

/// Extensión de tema que contiene roles semánticos adicionales
/// que no están cubiertos por el `ColorScheme` estándar.
class BiPiThemeExtension extends ThemeExtension<BiPiThemeExtension> {
  final Color background;
  final Color surfaceElevated;
  final Color textSecondary;
  final Color textMuted;
  final Color confrontationBackground;
  final Color confrontationBorder;
  final Color confrontationText;
  final Color disabledBackground;
  final Color disabledForeground;
  final Color warning;
  final Color success;

  const BiPiThemeExtension({
    required this.background,
    required this.surfaceElevated,
    required this.textSecondary,
    required this.textMuted,
    required this.confrontationBackground,
    required this.confrontationBorder,
    required this.confrontationText,
    required this.disabledBackground,
    required this.disabledForeground,
    required this.warning,
    required this.success,
  });

  static const light = BiPiThemeExtension(
    background: Color(0xFFFFF9F6),
    surfaceElevated: Color(0xFFFFF4F4),
    textSecondary: Color(0xFF606C5D),
    textMuted: Color(0xFF778174),
    confrontationBackground: Color(0xFFF7E6C4),
    confrontationBorder: Color(0xFF606C5D),
    confrontationText: Color(0xFF263229),
    disabledBackground: Color(0xFFE7E0D6),
    disabledForeground: Color(0xFF8C8A83),
    warning: Color(0xFF8A5A00),
    success: Color(0xFF1B5E20),
  );

  static const dark = BiPiThemeExtension(
    background: Color(0xFF1D241F),
    surfaceElevated: Color(0xFF303A32),
    textSecondary: Color(0xFFE5D8C2),
    textMuted: Color(0xFFB8B0A2),
    confrontationBackground: Color(0xFF3B382D),
    confrontationBorder: Color(0xFFF1C376),
    confrontationText: Color(0xFFFFF4F4),
    disabledBackground: Color(0xFF343B35),
    disabledForeground: Color(0xFF858E86),
    warning: Color(0xFFFFD54F),
    success: Color(0xFFA5D6A7),
  );

  @override
  BiPiThemeExtension copyWith({
    Color? background,
    Color? surfaceElevated,
    Color? textSecondary,
    Color? textMuted,
    Color? confrontationBackground,
    Color? confrontationBorder,
    Color? confrontationText,
    Color? disabledBackground,
    Color? disabledForeground,
    Color? warning,
    Color? success,
  }) {
    return BiPiThemeExtension(
      background: background ?? this.background,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      confrontationBackground:
      confrontationBackground ?? this.confrontationBackground,
      confrontationBorder: confrontationBorder ?? this.confrontationBorder,
      confrontationText: confrontationText ?? this.confrontationText,
      disabledBackground: disabledBackground ?? this.disabledBackground,
      disabledForeground: disabledForeground ?? this.disabledForeground,
      warning: warning ?? this.warning,
      success: success ?? this.success,
    );
  }

  @override
  BiPiThemeExtension lerp(
      covariant ThemeExtension<BiPiThemeExtension>? other, double t) {
    if (other is! BiPiThemeExtension) return this;
    return BiPiThemeExtension(
      background: Color.lerp(background, other.background, t)!,
      surfaceElevated:
      Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      confrontationBackground: Color.lerp(
          confrontationBackground, other.confrontationBackground, t)!,
      confrontationBorder:
      Color.lerp(confrontationBorder, other.confrontationBorder, t)!,
      confrontationText:
      Color.lerp(confrontationText, other.confrontationText, t)!,
      disabledBackground:
      Color.lerp(disabledBackground, other.disabledBackground, t)!,
      disabledForeground:
      Color.lerp(disabledForeground, other.disabledForeground, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// Adaptador de paleta que obtiene los colores desde `Theme.of(context)`.
/// No almacena valores; evita duplicación.
class AppPalette {
  final ColorScheme _colorScheme;
  final BiPiThemeExtension _extension;

  const AppPalette._(this._colorScheme, this._extension);

  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    final extension =
        theme.extension<BiPiThemeExtension>() ?? BiPiThemeExtension.light;
    return AppPalette._(theme.colorScheme, extension);
  }

  Color get background => _extension.background;
  Color get surface => _colorScheme.surface;
  Color get surfaceElevated => _extension.surfaceElevated;
  Color get textPrimary => _colorScheme.onSurface;
  Color get textSecondary => _extension.textSecondary;
  Color get textMuted => _extension.textMuted;
  Color get border => _colorScheme.outline;
  Color get primaryAction => _colorScheme.primary;
  Color get onPrimaryAction => _colorScheme.onPrimary;
  Color get destructive => _colorScheme.error;
  Color get onDestructive => _colorScheme.onError;
  Color get disabledBackground => _extension.disabledBackground;
  Color get disabledForeground => _extension.disabledForeground;
  Color get confrontationBackground => _extension.confrontationBackground;
  Color get confrontationBorder => _extension.confrontationBorder;
  Color get confrontationText => _extension.confrontationText;
  Color get warning => _extension.warning;
  Color get success => _extension.success;
}

/// Sistema tipográfico centralizado.
class AppTypography {
  AppTypography._();

  static TextStyle logo({required Color color, double size = 28}) =>
      GoogleFonts.radioCanadaBig(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.0,
      );

  static TextStyle screenTitle({required Color color, double size = 24}) =>
      GoogleFonts.radioCanadaBig(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle tagline({required Color color, double size = 14}) =>
      GoogleFonts.urbanist(
        fontSize: size,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: color,
      );

  static TextStyle body({required Color color, double size = 15}) =>
      GoogleFonts.urbanist(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle label({required Color color, double size = 13}) =>
      GoogleFonts.urbanist(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle button({required Color color, double size = 16}) =>
      GoogleFonts.urbanist(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.2,
      );

  static TextStyle valueStrong({required Color color, double size = 26}) =>
      GoogleFonts.urbanist(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle confrontationValue({
    required Color color,
    double size = 26,
  }) =>
      GoogleFonts.radioCanadaBig(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
      );
}

/// Tema claro completo.
ThemeData buildLightTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFF1C376),
    onPrimary: Color(0xFF263229),
    secondary: Color(0xFFFFF4F4),
    onSecondary: Color(0xFF263229),
    error: Color(0xFFA63D40),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF263229),
    outline: Color(0xFFDCCFBA),
    shadow: Colors.black26,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    textTheme: GoogleFonts.urbanistTextTheme(),
  );

  return base.copyWith(
    scaffoldBackgroundColor: BiPiThemeExtension.light.background,
    appBarTheme: AppBarTheme(
      backgroundColor: BiPiThemeExtension.light.background,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      titleTextStyle: AppTypography.screenTitle(color: colorScheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.onSurface,
      contentTextStyle: AppTypography.body(color: colorScheme.surface),
      actionTextColor: colorScheme.primary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      labelStyle: AppTypography.label(color: BiPiThemeExtension.light.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.onSurface, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        textStyle: AppTypography.button(color: colorScheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        minimumSize: const Size(44, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outline),
        textStyle: AppTypography.button(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        minimumSize: const Size(44, 44),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primary,
      labelStyle: AppTypography.label(color: colorScheme.onSurface),
      secondaryLabelStyle: AppTypography.label(color: colorScheme.onPrimary),
      side: BorderSide(color: colorScheme.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      modalBackgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      titleTextStyle: AppTypography.screenTitle(color: colorScheme.onSurface),
      contentTextStyle: AppTypography.body(color: colorScheme.onSurface),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colorScheme.surface,
      headerBackgroundColor: BiPiThemeExtension.light.surfaceElevated,
      headerForegroundColor: colorScheme.onSurface,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: colorScheme.surface,
      helpTextStyle: AppTypography.label(
        color: colorScheme.onSurface,
        size: 13,
      ),
      hourMinuteColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : BiPiThemeExtension.light.surfaceElevated,
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.onSurface,
      ),
      dialBackgroundColor: BiPiThemeExtension.light.surfaceElevated,
      dialHandColor: colorScheme.primary,
      dialTextColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.onSurface,
      ),
      dayPeriodColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : colorScheme.surface,
      ),
      dayPeriodTextColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.onSurface,
      ),
      dayPeriodBorderSide: BorderSide(
        color: colorScheme.outline,
      ),
      entryModeIconColor: colorScheme.onSurface,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : null,
      ),
    ),
    iconTheme: IconThemeData(color: colorScheme.onSurface),
    extensions: const [BiPiThemeExtension.light],
  );
}

/// Tema oscuro completo.
ThemeData buildDarkTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFF1C376),
    onPrimary: Color(0xFF263229),
    secondary: Color(0xFF303A32),
    onSecondary: Color(0xFFFFF4F4),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF4A090E),
    surface: Color(0xFF273029),
    onSurface: Color(0xFFFFF4F4),
    outline: Color(0xFF4C5A4E),
    shadow: Colors.black,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    textTheme: GoogleFonts.urbanistTextTheme(),
  );

  return base.copyWith(
    scaffoldBackgroundColor: BiPiThemeExtension.dark.background,
    appBarTheme: AppBarTheme(
      backgroundColor: BiPiThemeExtension.dark.background,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      titleTextStyle: AppTypography.screenTitle(color: colorScheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.primary,
      contentTextStyle: AppTypography.body(color: colorScheme.onPrimary),
      actionTextColor: colorScheme.onPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      labelStyle: AppTypography.label(color: BiPiThemeExtension.dark.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.onSurface, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        textStyle: AppTypography.button(color: colorScheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        minimumSize: const Size(44, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outline),
        textStyle: AppTypography.button(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        minimumSize: const Size(44, 44),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primary,
      labelStyle: AppTypography.label(color: colorScheme.onSurface),
      secondaryLabelStyle: AppTypography.label(color: colorScheme.onPrimary),
      side: BorderSide(color: colorScheme.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      modalBackgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      titleTextStyle: AppTypography.screenTitle(color: colorScheme.onSurface),
      contentTextStyle: AppTypography.body(color: colorScheme.onSurface),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colorScheme.surface,
      headerBackgroundColor: BiPiThemeExtension.dark.surfaceElevated,
      headerForegroundColor: colorScheme.onSurface,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: colorScheme.surface,
      helpTextStyle: AppTypography.label(
        color: colorScheme.onSurface,
        size: 13,
      ),
      hourMinuteColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : BiPiThemeExtension.dark.surfaceElevated,
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.onSurface,
      ),
      dialBackgroundColor: BiPiThemeExtension.dark.surfaceElevated,
      dialHandColor: colorScheme.primary,
      dialTextColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.onSurface,
      ),
      dayPeriodColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : colorScheme.surface,
      ),
      dayPeriodTextColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.onSurface,
      ),
      dayPeriodBorderSide: BorderSide(
        color: colorScheme.outline,
      ),
      entryModeIconColor: colorScheme.onSurface,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : null,
      ),
    ),
    iconTheme: IconThemeData(color: colorScheme.onSurface),
    extensions: const [BiPiThemeExtension.dark],
  );
}