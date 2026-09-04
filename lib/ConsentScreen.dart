import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'AppColors.dart';
import 'ConsentService.dart';
import 'ConsentDocumentContent.dart';
import 'ThemeToggleButton.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  final _consentService = ConsentService();

  bool _accepted = false;
  bool _isAccepting = false;
  bool _isSigningOut = false;
  String? _error;
  String? _signOutError;

  Future<void> _accept() async {
    setState(() {
      _isAccepting = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isAccepting = false;
        _error = 'No se pudo identificar al usuario.';
      });
      return;
    }

    try {
      await _consentService.acceptConsent(userId: user.uid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAccepting = false;
        _error = 'No se pudo registrar el consentimiento. '
            'Revisa tu conexión e inténtalo nuevamente.';
      });
    }
  }

  Future<void> _noParticipate() async {
    setState(() {
      _isSigningOut = true;
      _signOutError = null;
    });

    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSigningOut = false;
        _signOutError = 'No se pudo cerrar sesión. Inténtalo nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  ThemeToggleButton(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Consentimiento informado',
                style: AppTypography.screenTitle(color: palette.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'BiPi · Piloto académico',
                style: AppTypography.label(color: palette.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const ConsentDocumentContent(),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _accepted,
                      onChanged: (_isAccepting || _isSigningOut)
                          ? null
                          : (value) =>
                          setState(() => _accepted = value ?? false),
                      activeColor: palette.primaryAction,
                      checkColor: palette.onPrimaryAction,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: (_isAccepting || _isSigningOut)
                            ? null
                            : () => setState(() => _accepted = !_accepted),
                        child: Text(
                          'Confirmo que tengo 18 años o más y acepto participar '
                              'voluntariamente en este piloto.',
                          style: AppTypography.body(color: palette.textPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTypography.body(color: palette.destructive),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_signOutError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _signOutError!,
                  style: AppTypography.body(color: palette.destructive),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_accepted && !_isAccepting && !_isSigningOut)
                    ? _accept
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryAction,
                  foregroundColor: palette.onPrimaryAction,
                  disabledBackgroundColor: palette.disabledBackground,
                  disabledForegroundColor: palette.disabledForeground,
                  minimumSize: const Size(double.infinity, 52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isAccepting
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: palette.onPrimaryAction,
                  ),
                )
                    : Text(
                  'ACEPTO PARTICIPAR',
                  style: AppTypography.button(
                      color: palette.onPrimaryAction, size: 16),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: (_isAccepting || _isSigningOut)
                    ? null
                    : _noParticipate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.textPrimary,
                  side: BorderSide(color: palette.border),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSigningOut
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: palette.textPrimary,
                  ),
                )
                    : Text(
                  'NO PARTICIPAR',
                  style: AppTypography.button(
                      color: palette.textPrimary, size: 14),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}