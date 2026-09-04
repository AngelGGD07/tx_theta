import 'package:flutter/material.dart';

import 'AppColors.dart';
import 'ConsentDocumentContent.dart';
import 'ConsentService.dart';
import 'ThemeToggleButton.dart';

class ConsentDocumentScreen extends StatelessWidget {
  final String consentVersion;

  const ConsentDocumentScreen({
    super.key,
    required this.consentVersion,
  });

  bool get _isSupportedVersion {
    return consentVersion == ConsentService.currentConsentVersion;
  }

  String get _displayVersion {
    if (_isSupportedVersion) {
      return 'Versión del piloto 2026.01';
    }

    return 'Versión no disponible';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSupportedVersion
              ? 'Consentimiento informado del piloto'
              : 'Documento no disponible',
          style: AppTypography.screenTitle(
            color: palette.textPrimary,
            size: 20,
          ),
        ),
        actions: const [
          ThemeToggleButton(),
        ],
      ),
      body: SafeArea(
        child: _isSupportedVersion
            ? SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _displayVersion,
                style: AppTypography.label(
                  color: palette.textMuted,
                  size: 13,
                ),
              ),
              const SizedBox(height: 24),
              const ConsentDocumentContent(),
            ],
          ),
        )
            : Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 56,
                  color: palette.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'No podemos mostrar la versión de consentimiento que aceptaste.',
                  textAlign: TextAlign.center,
                  style: AppTypography.screenTitle(
                    color: palette.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contacta al responsable del piloto para solicitar una copia.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    color: palette.textSecondary,
                    size: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}