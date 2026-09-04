import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'AppColors.dart';
import 'ConsentService.dart';
import 'PilotErrorReport.dart';
import 'ThemeToggleButton.dart';

class PilotErrorReportScreen extends StatefulWidget {
  final String initialArea;

  const PilotErrorReportScreen({
    super.key,
    this.initialArea = 'Otro',
  });

  @override
  State<PilotErrorReportScreen> createState() =>
      _PilotErrorReportScreenState();
}

class _PilotErrorReportScreenState extends State<PilotErrorReportScreen> {
  static const List<String> _allowedAreas = [
    'Acceso y cuenta',
    'Nueva responsabilidad',
    'Notificaciones',
    'Registrar inicio',
    'Consentimiento',
    'Navegación o pantalla',
    'Otro',
  ];

  final TextEditingController _descriptionController =
  TextEditingController();

  String _area = 'Otro';
  String _suffix = '';
  bool _isSharing = false;

  String get _prefix {
    switch (_area) {
      case 'Acceso y cuenta':
        return 'BP-AUTH';
      case 'Nueva responsabilidad':
        return 'BP-CAPTURE';
      case 'Notificaciones':
        return 'BP-NOTIFY';
      case 'Registrar inicio':
        return 'BP-START';
      case 'Consentimiento':
        return 'BP-CONSENT';
      case 'Navegación o pantalla':
        return 'BP-UI';
      case 'Otro':
      default:
        return 'BP-GENERAL';
    }
  }

  String get _code => '$_prefix-$_suffix';

  String get _platformName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isFuchsia) return 'Fuchsia';
    return 'Desconocido';
  }

  @override
  void initState() {
    super.initState();
    _suffix = _generateSuffix();
    _area = _allowedAreas.contains(widget.initialArea)
        ? widget.initialArea
        : 'Otro';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String _generateSuffix() {
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    final base36 = nowMicros.toRadixString(36).toUpperCase();
    final usable = base36.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final value = usable.padRight(4, '0');
    return value.substring(value.length - 4);
  }

  PilotErrorReport _buildReport() {
    return PilotErrorReport(
      code: _code,
      area: _area,
      description: _descriptionController.text.trim(),
      appVersion: ConsentService.currentAppVersion,
      platform: _platformName,
      createdAt: DateTime.now(),
    );
  }

  String? _validateDescription() {
    final trimmed = _descriptionController.text.trim();
    if (trimmed.length < 10) {
      return 'Describe brevemente qué ocurrió.';
    }
    return null;
  }

  Future<void> _shareReport() async {
    if (_isSharing) return;

    final error = _validateDescription();
    if (error != null) {
      _showMessage(error);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _isSharing = true);

    try {
      final report = _buildReport();

      final result = await Share.share(
        report.toShareText(),
        subject: 'Reporte BiPi · ${report.code}',
      );

      if (!mounted) return;

      switch (result.status) {
        case ShareResultStatus.success:
          _showMessage('Se compartió el reporte.');
          break;
        case ShareResultStatus.dismissed:
          break;
        case ShareResultStatus.unavailable:
          _showMessage(
            'No pudimos abrir las opciones para compartir. Puedes copiar el reporte.',
          );
          break;
      }
    } catch (e) {
      debugPrint('Share report error: ${e.runtimeType}');
      if (!mounted) return;
      _showMessage(
        'No pudimos abrir las opciones para compartir. Puedes copiar el reporte.',
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _copyReport() async {
    if (_isSharing) return;

    final error = _validateDescription();
    if (error != null) {
      _showMessage(error);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final report = _buildReport();

    try {
      await Clipboard.setData(
        ClipboardData(text: report.toShareText()),
      );

      if (!mounted) return;
      _showMessage('Reporte copiado.');
    } catch (e) {
      debugPrint('Copy report error: ${e.runtimeType}');
      if (!mounted) return;
      _showMessage('No pudimos copiar el reporte.');
    }
  }

  void _showMessage(String message) {
    final palette = AppPalette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.body(color: palette.surface),
        ),
        backgroundColor: palette.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final code = _code;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reportar un problema',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cuéntanos qué estabas intentando hacer y qué ocurrió. '
                    'Prepararemos un reporte para que puedas compartirlo con el responsable del piloto.',
                style: AppTypography.body(
                  color: palette.textSecondary,
                  size: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No incluyas contraseñas, enlaces de acceso, códigos de verificación ni información académica sensible.',
                style: AppTypography.body(
                  color: palette.textMuted,
                  size: 13,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Área del problema',
                style: AppTypography.label(
                  color: palette.textPrimary,
                  size: 15,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildAreaChip('Acceso y cuenta'),
                  _buildAreaChip('Nueva responsabilidad'),
                  _buildAreaChip('Notificaciones'),
                  _buildAreaChip('Registrar inicio'),
                  _buildAreaChip('Consentimiento'),
                  _buildAreaChip('Navegación o pantalla'),
                  _buildAreaChip('Otro'),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '¿Qué ocurrió?',
                style: AppTypography.label(
                  color: palette.textPrimary,
                  size: 15,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                enabled: !_isSharing,
                minLines: 4,
                maxLines: 6,
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                style: AppTypography.body(color: palette.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Describe los pasos y el resultado que viste.',
                  hintStyle: AppTypography.body(
                    color: palette.textMuted,
                    size: 14,
                  ),
                  labelText: 'Descripción',
                  labelStyle: AppTypography.label(
                    color: palette.textMuted,
                  ),
                  filled: true,
                  fillColor: palette.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: palette.textPrimary, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Código del reporte',
                style: AppTypography.label(
                  color: palette.textPrimary,
                  size: 15,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                code,
                style: AppTypography.valueStrong(
                  color: palette.textPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSharing ? null : _shareReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryAction,
                  foregroundColor: palette.onPrimaryAction,
                  disabledBackgroundColor: palette.disabledBackground,
                  disabledForegroundColor: palette.disabledForeground,
                  minimumSize: const Size.fromHeight(52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSharing
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: palette.onPrimaryAction,
                  ),
                )
                    : Text(
                  'ENVIAR REPORTE',
                  style: AppTypography.button(
                    color: palette.onPrimaryAction,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _isSharing ? null : _copyReport,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.textPrimary,
                  side: BorderSide(color: palette.border),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'COPIAR',
                  style: AppTypography.button(
                    color: palette.textPrimary,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAreaChip(String label) {
    final palette = AppPalette.of(context);
    final selected = _area == label;

    return ChoiceChip(
      label: Text(
        label,
        style: AppTypography.label(
          color: selected ? palette.onPrimaryAction : palette.textPrimary,
          size: 13,
        ),
      ),
      selected: selected,
      selectedColor: palette.primaryAction,
      backgroundColor: palette.surface,
      disabledColor: palette.surface,
      side: BorderSide(color: palette.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onSelected: _isSharing
          ? null
          : (_) {
        setState(() {
          _area = label;
        });
      },
    );
  }
}