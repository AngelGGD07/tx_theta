import 'package:flutter/material.dart';

import 'AppColors.dart';
import 'ThemeModeController.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? 'Usar modo claro' : 'Usar modo oscuro',
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: palette.textPrimary,
      ),
      onPressed: () {
        themeModeNotifier.value =
        isDark ? ThemeMode.light : ThemeMode.dark;
      },
    );
  }
}