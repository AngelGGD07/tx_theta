import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Botón "Continuar con Google", implementado siguiendo la
/// especificación de Google Identity Services.
///
/// Esta es la única parte de la aplicación que utiliza Roboto en lugar de
/// Figtree, debido a los lineamientos visuales del botón de Google.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  /// Icono utilizado cuando la aplicación muestra el tema claro.
  final String lightAssetPath;

  /// Icono utilizado cuando la aplicación muestra el tema oscuro.
  final String darkAssetPath;

  final bool stretch;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.lightAssetPath = 'assets/google.png',
    this.darkAssetPath = 'assets/google_dark.png',
    this.stretch = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF131314)
        : Colors.white;

    final borderColor = isDark
        ? const Color(0xFF8E918F)
        : const Color(0xFF747775);

    final textColor = isDark
        ? const Color(0xFFE3E3E3)
        : const Color(0xFF1F1F1F);

    final iconAssetPath = isDark
        ? darkAssetPath
        : lightAssetPath;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Image.asset(
            iconAssetPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.g_mobiledata,
                size: 20,
                color: textColor,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
            letterSpacing: 0.25,
          ),
        ),
      ],
    );

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: borderColor,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 40,
          width: stretch ? double.infinity : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}