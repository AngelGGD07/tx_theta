import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'AppColors.dart';
import 'ThemeToggleButton.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  final bool useEnglish;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.useEnglish = false,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;

  bool _isSending = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  bool get _useEnglish => widget.useEnglish;

  String _t(String es, String en) => _useEnglish ? en : es;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: widget.initialEmail,
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = 90;
    });

    _cooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_cooldownSeconds <= 1) {
          timer.cancel();
          setState(() {
            _cooldownSeconds = 0;
          });
          return;
        }

        setState(() {
          _cooldownSeconds--;
        });
      },
    );
  }

  Future<void> _sendResetEmail() async {
    if (_isSending || _cooldownSeconds > 0) return;

    FocusManager.instance.primaryFocus?.unfocus();

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage(
        _t('Introduce tu correo.', 'Enter your email.'),
      );
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage(
        _t('Introduce un correo válido.', 'Enter a valid email.'),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await FirebaseAuth.instance.setLanguageCode(
        _useEnglish ? 'en' : 'es',
      );

      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      _showMessage(
        _t(
          'Si existe una cuenta asociada a ese correo, recibirás un enlace '
              'para restablecer la contraseña.',
          "If an account is associated with that email, you'll receive a "
              'password reset link.',
        ),
      );

      _startCooldown();
    } on FirebaseAuthException catch (e) {
      debugPrint('Forgot password FirebaseAuthException code: ${e.code}');

      if (!mounted) return;

      switch (e.code) {
        case 'invalid-email':
          _showMessage(
            _t('Introduce un correo válido.', 'Enter a valid email.'),
          );
          break;
        case 'network-request-failed':
          _showMessage(
            _t(
              'No pudimos conectarnos. Revisa tu conexión e inténtalo nuevamente.',
              "We couldn't connect. Check your internet connection and try again.",
            ),
          );
          break;
        case 'too-many-requests':
          _showMessage(
            _t(
              'Demasiados intentos. Espera un momento antes de volver a intentarlo.',
              'Too many attempts. Please wait before trying again.',
            ),
          );
          _startCooldown();
          break;
        case 'user-not-found':
          _showMessage(
            _t(
              'Si existe una cuenta asociada a ese correo, recibirás un enlace '
                  'para restablecer la contraseña.',
              "If an account is associated with that email, you'll receive a "
                  'password reset link.',
            ),
          );
          _startCooldown();
          break;
        default:
          _showMessage(
            _t(
              'No pudimos enviar el enlace. Inténtalo nuevamente.',
              "We couldn't send the link. Please try again.",
            ),
          );
      }
    } on TimeoutException {
      debugPrint('Forgot password timeout');
      if (!mounted) return;
      _showMessage(
        _t(
          'No pudimos conectarnos. Revisa tu conexión e inténtalo nuevamente.',
          "We couldn't connect. Check your internet connection and try again.",
        ),
      );
    } catch (e) {
      debugPrint(
        'Forgot password unexpected error: ${e.runtimeType}',
      );
      if (!mounted) return;
      _showMessage(
        _t(
          'No pudimos enviar el enlace. Inténtalo nuevamente.',
          "We couldn't send the link. Please try again.",
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
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

    final buttonLabel = _cooldownSeconds > 0
        ? _t(
      'REENVIAR EN $_cooldownSeconds S',
      'RESEND IN $_cooldownSeconds S',
    )
        : _t('ENVIAR ENLACE', 'SEND LINK');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('Recuperar contraseña', 'Reset password'),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.lock_reset_outlined,
                size: 56,
                color: palette.textPrimary,
              ),
              const SizedBox(height: 24),
              Text(
                _t(
                  'Introduce el correo asociado a tu cuenta. Te enviaremos '
                      'un enlace para crear una contraseña nueva.',
                  'Enter the email associated with your account. '
                      "We'll send you a link to create a new password.",
                ),
                style: AppTypography.body(
                  color: palette.textSecondary,
                  size: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'Revisa también Spam o Correo no deseado.',
                  'Also check your Spam or Junk folder.',
                ),
                style: AppTypography.body(
                  color: palette.textMuted,
                  size: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                enabled: !_isSending,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sendResetEmail(),
                style: AppTypography.body(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: _t(
                    'Correo electrónico',
                    'Email address',
                  ),
                  labelStyle: AppTypography.label(color: palette.textMuted),
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
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.border),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_isSending || _cooldownSeconds > 0)
                    ? null
                    : _sendResetEmail,
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
                child: _isSending
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: palette.onPrimaryAction,
                  ),
                )
                    : Text(
                  buttonLabel,
                  style: AppTypography.button(
                    color: palette.onPrimaryAction,
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