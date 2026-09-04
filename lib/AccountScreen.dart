import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'AppColors.dart';
import 'ConsentDocumentScreen.dart';
import 'ConsentService.dart';
import 'PilotErrorReportScreen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isResettingPassword = false;
  bool _isSigningOut = false;
  bool _isUpdatingName = false;
  bool _isLoadingConsent = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  List<String> get _providers =>
      _user?.providerData.map((info) => info.providerId).toList() ?? [];

  bool get _hasPasswordProvider => _providers.contains('password');
  bool get _hasGoogleProvider => _providers.contains('google.com');
  bool get _hasMicrosoftProvider => _providers.contains('microsoft.com');

  bool get _hasUnknownProvider => _providers.any(
        (provider) =>
    provider != 'password' &&
        provider != 'google.com' &&
        provider != 'microsoft.com',
  );

  bool get _isBusy =>
      _isUpdatingName ||
          _isResettingPassword ||
          _isSigningOut ||
          _isLoadingConsent;

  Future<void> _resetPassword() async {
    if (_isBusy) return;

    final email = _user?.email;
    if (email == null || email.isEmpty) {
      _showMessage(
          'No tienes un correo registrado para restablecer contraseña.');
      return;
    }

    setState(() => _isResettingPassword = true);

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      _showMessage('Te enviamos un enlace para restablecer tu contraseña.');
    } catch (e) {
      debugPrint('Reset password error: ${e.runtimeType}');
      if (!mounted) return;
      _showMessage(
        'No pudimos enviar el enlace. Revisa tu conexión e inténtalo nuevamente.',
      );
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  Future<void> _signOut() async {
    if (_isBusy) return;

    setState(() => _isSigningOut = true);

    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Sign out error: ${e.runtimeType}');
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      _showMessage('No se pudo cerrar sesión. Inténtalo nuevamente.');
    }
  }

  Future<void> _editName() async {
    if (_isBusy) return;

    final currentName =
        FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';

    final result = await showModalBottomSheet<_NameEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NameEditSheet(initialName: currentName),
    );

    if (result == null || !mounted) return;

    setState(() => _isUpdatingName = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        _showMessage(
          'No pudimos actualizar el nombre. Inicia sesión nuevamente.',
        );
        return;
      }

      if (result.remove) {
        await user.updateDisplayName(null);
      } else {
        await user.updateDisplayName(result.value);
      }

      await user.reload();

      if (!mounted) return;
      setState(() {});
      _showMessage(
        result.remove ? 'Nombre eliminado de BiPi.' : 'Nombre actualizado.',
      );
    } catch (e) {
      debugPrint('Update display name error: ${e.runtimeType}');
      if (!mounted) return;
      _showMessage(
        'No pudimos actualizar el nombre. Revisa tu conexión e inténtalo nuevamente.',
      );
    } finally {
      if (mounted) setState(() => _isUpdatingName = false);
    }
  }

  Future<String?> _loadConsentVersion() async {
    final user = _user;
    if (user == null) return null;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(ConsentService.collectionName)
          .doc(user.uid)
          .get();

      if (!snapshot.exists) return null;

      return snapshot.data()?['consentVersion'] as String?;
    } catch (e) {
      debugPrint('Load consent version error: ${e.runtimeType}');
      return null;
    }
  }

  Future<bool?> _showConsentVersionError() async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final palette = AppPalette.of(context);

        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'No pudimos cargar la versión de tu consentimiento.',
            style: AppTypography.screenTitle(
              color: palette.textPrimary,
              size: 20,
            ),
          ),
          content: Text(
            'Inténtalo nuevamente. Si el problema continúa, contacta al responsable del piloto.',
            style: AppTypography.body(color: palette.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'VOLVER',
                style: AppTypography.button(
                  color: palette.textPrimary,
                  size: 14,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'REINTENTAR',
                style: AppTypography.button(
                  color: palette.primaryAction,
                  size: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openConsentDocument() async {
    if (_isBusy) return;

    setState(() => _isLoadingConsent = true);

    String? version;

    try {
      version = await _loadConsentVersion();
    } finally {
      if (mounted) {
        setState(() => _isLoadingConsent = false);
      }
    }

    if (!mounted) return;

    if (version == null || version.isEmpty) {
      final retry = await _showConsentVersionError();

      if (retry == true && mounted) {
        await _openConsentDocument();
      }

      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConsentDocumentScreen(
          consentVersion: version!,
        ),
      ),
    );
  }

  void _openProblemReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PilotErrorReportScreen(),
      ),
    );
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
    final user = _user;
    final displayName = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : 'Nombre no configurado';
    final email = (user?.email?.isNotEmpty ?? false)
        ? user!.email!
        : 'Correo no configurado';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSection(palette, 'Nombre en BiPi', displayName),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: _isBusy ? null : _editName,
              child: _isUpdatingName
                  ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: palette.textPrimary,
                ),
              )
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit,
                    size: 16,
                    color: palette.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Editar',
                    style: AppTypography.button(
                      color: palette.textPrimary,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSection(palette, 'Correo', email),
          const SizedBox(height: 24),
          Text(
            'Métodos de acceso',
            style: AppTypography.label(
              color: palette.textPrimary,
              size: 15,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_hasPasswordProvider) ...[
            _buildProviderInfo(
              palette,
              'Correo y contraseña',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _isBusy ? null : _resetPassword,
                child: _isResettingPassword
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: palette.textPrimary,
                  ),
                )
                    : const Text('Restablecer contraseña'),
              ),
            ),
          ],
          if (_hasGoogleProvider) ...[
            const SizedBox(height: 12),
            _buildProviderInfo(
              palette,
              'Google',
              extra:
              'La contraseña se administra desde tu cuenta de Google.',
            ),
          ],
          if (_hasMicrosoftProvider) ...[
            const SizedBox(height: 12),
            _buildProviderInfo(
              palette,
              'Microsoft',
              extra:
              'La contraseña se administra desde tu cuenta de Microsoft.',
            ),
          ],
          if (_hasUnknownProvider) ...[
            const SizedBox(height: 12),
            _buildProviderInfo(
              palette,
              'Otro método de acceso',
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _isBusy ? null : _signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.destructive,
                side: BorderSide(color: palette.destructive),
              ),
              child: _isSigningOut
                  ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: palette.destructive,
                ),
              )
                  : const Text('CERRAR SESIÓN'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _isBusy ? null : _openProblemReport,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: palette.textPrimary,
              ),
              icon: Icon(
                Icons.report_problem_outlined,
                size: 16,
                color: palette.textPrimary,
              ),
              label: Text(
                'Reportar un problema',
                style: AppTypography.label(
                  color: palette.textPrimary,
                  size: 13,
                ),
              ),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: _isBusy ? null : _openConsentDocument,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: palette.textPrimary,
              ),
              icon: _isLoadingConsent
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.textPrimary,
                ),
              )
                  : Icon(
                Icons.description_outlined,
                size: 16,
                color: palette.textPrimary,
              ),
              label: Text(
                'Consentimiento del piloto',
                style: AppTypography.label(
                  color: palette.textPrimary,
                  size: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(AppPalette palette, String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.label(
            color: palette.textMuted,
            size: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.body(
            color: palette.textPrimary,
            size: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildProviderInfo(
      AppPalette palette,
      String name, {
        String? extra,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: palette.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: AppTypography.body(
                color: palette.textPrimary,
                size: 15,
              ),
            ),
          ],
        ),
        if (extra != null) ...[
          const SizedBox(height: 4),
          Text(
            extra,
            style: AppTypography.body(
              color: palette.textSecondary,
              size: 14,
            ),
          ),
        ],
      ],
    );
  }
}

class _NameEditResult {
  final bool remove;
  final String? value;

  const _NameEditResult.update(String name)
      : remove = false,
        value = name;

  const _NameEditResult.remove()
      : remove = true,
        value = null;
}

class _NameEditSheet extends StatefulWidget {
  final String initialName;

  const _NameEditSheet({required this.initialName});

  @override
  State<_NameEditSheet> createState() => _NameEditSheetState();
}

class _NameEditSheetState extends State<_NameEditSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      if (trimmed.length < 2) {
        return 'El nombre debe tener al menos 2 caracteres.';
      }
      if (trimmed.length > 50) {
        return 'El nombre no puede superar 50 caracteres.';
      }
    }
    return null;
  }

  void _save() {
    final trimmed = _controller.text.trim();
    final error = _validate(trimmed);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    if (trimmed.isEmpty) {
      Navigator.of(context).pop(const _NameEditResult.remove());
    } else {
      Navigator.of(context).pop(_NameEditResult.update(trimmed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: palette.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  decoration: BoxDecoration(
                    color: palette.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Editar nombre',
                style: AppTypography.screenTitle(
                  color: palette.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 1,
                maxLength: 50,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() => _error = null);
                  }
                },
                style: AppTypography.body(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nombre en BiPi',
                  labelStyle: AppTypography.label(color: palette.textMuted),
                  filled: true,
                  fillColor: palette.surface,
                  counterText: '',
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
              if (widget.initialName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Deja el campo vacío para quitar el nombre de BiPi.',
                  style: AppTypography.body(
                    color: palette.textSecondary,
                    size: 13,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: AppTypography.body(color: palette.destructive),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'CANCELAR',
                      style: AppTypography.button(
                        color: palette.textPrimary,
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _save,
                    child: Text(
                      'GUARDAR',
                      style: AppTypography.button(
                        color: palette.primaryAction,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}