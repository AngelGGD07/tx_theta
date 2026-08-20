import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores de marca fijos (logo, acentos). No cambian entre modo
/// claro/oscuro — son la identidad visual de BiPi en cualquier contexto.
class AppColors {
  AppColors._();

  static const amber = Color(0xFFFFCC70);
  static const cream = Color(0xFFFFFADD);
  static const skyBlue = Color(0xFF8ECDDD);
  static const deepBlue = Color(0xFF22668D);
}

/// Paleta que SÍ cambia según el modo claro/oscuro. Úsala para fondo,
/// superficie y texto en vez de AppColors directamente — así cada pantalla
/// se adapta sola sin lógica repetida.
class AppPalette {
  final Color background;
  final Color surface; // tarjetas, inputs
  final Color textPrimary;
  final Color textMuted;
  final Color border;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
  });

  static const light = AppPalette(
    background: Color(0xFFFFFDF7),
    surface: Colors.white,
    textPrimary: AppColors.deepBlue,
    textMuted: Color(0xFF5C7C90),
    border: Color(0x668ECDDD),
  );

  static const dark = AppPalette(
    background: Color(0xFF11151A),
    surface: Color(0xFF1B2129),
    textPrimary: Color(0xFFE7EEF3),
    textMuted: Color(0xFF9CB3C2),
    border: Color(0x558ECDDD),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Sistema tipográfico: Sanchez es la voz del espejo (interpreta),
/// Sora es la evidencia y la interacción (demuestra).
/// Todos los métodos piden el color explícitamente — así te obligas a
/// pasar el color correcto según AppPalette.of(context) y no se te olvida
/// adaptarlo en modo oscuro.
class AppTypography {
  AppTypography._();

  static TextStyle logo({required Color color, double size = 34}) =>
      GoogleFonts.sanchez(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.0,
      );

  static TextStyle tagline({required Color color, double size = 14}) =>
      GoogleFonts.sanchez(
        fontSize: size,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle screenTitle({required Color color, double size = 24}) =>
      GoogleFonts.sanchez(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle body({required Color color, double size = 15}) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle label({required Color color, double size = 13}) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle button({required Color color, double size = 15}) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.2,
      );

  static TextStyle valueStrong({required Color color, double size = 26}) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
      );
}

/// ThemeData para MaterialApp(theme: ..., darkTheme: ..., themeMode: ...).
/// Estos definen el look base de widgets que no usan AppTypography
/// directamente (SnackBars por defecto, etc.); las pantallas construidas
/// a mano (login, home) siguen leyendo AppPalette.of(context) igual.
ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppPalette.light.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.deepBlue,
      brightness: Brightness.light,
    ),
    fontFamily: GoogleFonts.sora().fontFamily,
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppPalette.dark.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.deepBlue,
      brightness: Brightness.dark,
    ),
    fontFamily: GoogleFonts.sora().fontFamily,
  );
}