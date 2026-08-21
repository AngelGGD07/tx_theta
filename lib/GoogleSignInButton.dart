import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Botón "Continuar con Google", implementado siguiendo al pixel la
/// especificación oficial de Google Identity Services (gsi-material-button):
/// altura 40dp, radio 4px, borde e icono de 20dp con 12px de separación,
/// tipografía Roboto 14/500 con letter-spacing 0.25.
///
/// IMPORTANTE: esta es la única parte de la app que usa Roboto en vez de
/// Sora — es un requisito de marca de Google, no una inconsistencia.
/// No cambies la tipografía ni los colores de este widget para que combine
/// con el resto de la app; eso rompería el cumplimiento de sus lineamientos.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final String assetPath;
  final bool stretch;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.assetPath = 'assets/google.png',
    this.stretch = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colores exactos de la variante "outline" de la spec oficial.
    final backgroundColor = isDark ? const Color(0xFF131314) : Colors.white;
    final borderColor =
    isDark ? const Color(0xFF8E918F) : const Color(0xFF747775);
    final textColor = isDark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.g_mobiledata, size: 20),
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

    // MEJORA FLUTTER: Pasamos el borde y el color directamente al Material
    // para que el InkWell (efecto de toque) se renderice perfectamente encima.
    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 40,
          width: stretch ? double.infinity : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: content,
          ),
        ),
      ),
    );
  }
}