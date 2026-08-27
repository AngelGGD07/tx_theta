import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Botón "Continuar con Microsoft".
///
/// Mantiene una composición visual coherente con el bloque de autenticación,
/// pero conserva la identidad propia del proveedor Microsoft.
///
/// Usa el símbolo oficial de Microsoft en sus cuatro colores originales.
/// No se recolorea ni se aplica ColorFiltered.
///
/// Por coherencia óptica en Android, este botón utiliza Roboto como
/// tipografía, al igual que el botón de Google. Esta excepción queda
/// limitada únicamente al botón del proveedor.
class MicrosoftSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final String assetPath;

  const MicrosoftSignInButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.assetPath = 'assets/microsoft.png',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = onPressed != null;

    final backgroundColor = isDark
        ? const Color(0xFF131314)
        : Colors.white;

    final borderColor = isDark
        ? const Color(0xFF8E918F)
        : const Color(0xFF747775);

    final textColor = isDark
        ? const Color(0xFFE3E3E3)
        : const Color(0xFF1F1F1F);

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: borderColor, width: 1),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 40,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Opacity(
              opacity: isEnabled ? 1.0 : 0.55,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: Image.asset(
                        assetPath,
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Microsoft asset error: $error');
                          return const SizedBox.shrink();
                        },
                      ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}