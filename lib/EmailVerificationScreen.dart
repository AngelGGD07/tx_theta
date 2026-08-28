import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'AppColors.dart';
import 'ThemeToggleButton.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_cooldownSeconds > 0) {
            _cooldownSeconds--;
          } else {
            timer.cancel();
          }
        });
      },
    );
  }

  Future<void> _checkVerified() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);

    try {
      final user = _user;
      if (user == null) return;

      await user.reload();
      if (!mounted) return;

      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) return;

      if (!refreshedUser.emailVerified) {
        _showMessage('El correo todavía no aparece como verificado.');
        return;
      }

      await refreshedUser.getIdToken(true);
      await refreshedUser.reload();

      // AuthGate con userChanges reaccionará y mostrará ConsentGate.
    } catch (e) {
      debugPrint('Email verification check error: $e');
      if (mounted) {
        _showMessage(
            'No pudimos verificar tu correo. Revisa tu conexión e inténtalo nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    if (_isResending || _cooldownSeconds > 0) return;

    setState(() => _isResending = true);

    try {
      final user = _user;
      if (user == null) return;

      await FirebaseAuth.instance.setLanguageCode('es');
      await user.sendEmailVerification();

      if (!mounted) return;
      _showMessage('Enviamos un nuevo enlace de verificación.');

      _startCooldown();
    } on FirebaseAuthException catch (e) {
      debugPrint('Resend verification error: $e');
      if (!mounted) return;
      if (e.code == 'too-many-requests') {
        _showMessage(
            'Demasiados intentos. Espera un momento antes de volver a intentarlo.');
      } else {
        _showMessage(
            'No pudimos reenviar el enlace. Revisa tu conexión e inténtalo nuevamente.');
      }
    } catch (e) {
      debugPrint('Resend verification error: $e');
      if (mounted) {
        _showMessage(
            'No pudimos reenviar el enlace. Revisa tu conexión e inténtalo nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _changeEmail() async {
    await FirebaseAuth.instance.signOut();
    // AuthGate mostrará LoginScreen.
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
    final email = user?.email?.isNotEmpty == true ? user!.email! : '';

    final resendLabel = _cooldownSeconds > 0
        ? 'Reenviar en $_cooldownSeconds s'
        : 'REENVIAR';

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: ThemeToggleButton(),
              ),
              const SizedBox(height: 16),
              Icon(
                Icons.mark_email_unread_outlined,
                size: 56,
                color: palette.textPrimary,
              ),
              const SizedBox(height: 24),
              Text(
                'Verifica tu correo',
                style: AppTypography.screenTitle(
                  color: palette.textPrimary,
                  size: 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Enviamos un enlace de verificación a $email. '
                    'Ábrelo y luego vuelve a BiPi.',
                style: AppTypography.body(
                  color: palette.textSecondary,
                  size: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Revisa también Spam o Correo no deseado.',
                style: AppTypography.body(
                  color: palette.textMuted,
                  size: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isChecking ? null : _checkVerified,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryAction,
                  foregroundColor: palette.onPrimaryAction,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isChecking
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: palette.onPrimaryAction,
                  ),
                )
                    : Text(
                  'YA VERIFIQUÉ',
                  style: AppTypography.button(
                    color: palette.onPrimaryAction,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: (_isResending || _cooldownSeconds > 0)
                    ? null
                    : _resendEmail,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.textPrimary,
                  side: BorderSide(color: palette.border),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isResending
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: palette.textPrimary,
                  ),
                )
                    : Text(
                  resendLabel,
                  style: AppTypography.button(
                    color: palette.textPrimary,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _changeEmail,
                child: Text(
                  'CAMBIAR CORREO',
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
}