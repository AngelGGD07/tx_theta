import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:BiPi/AppColors.dart';
import 'package:BiPi/GoogleSignInButton.dart';
import 'package:BiPi/MicrosoftSignInButton.dart';
import 'package:BiPi/ThemeToggleButton.dart';
import 'package:BiPi/ForgotPasswordScreen.dart';

/// -----------------------------------------------------------------------
/// Idiomas soportados. Se puede ampliar fácilmente agregando más entradas.
/// -----------------------------------------------------------------------
enum AppLanguage { es, en }

class _Strings {
  static const Map<AppLanguage, Map<String, String>> _values = {
    AppLanguage.es: {
      'tagline': 'Best Planner',
      'login_title': 'Iniciar sesión',
      'signup_title': 'Crear cuenta',
      'email': 'Correo institucional o personal',
      'password_login': 'Contraseña',
      'password_signup': 'Contraseña, mínimo 6 caracteres',
      'enter': 'Entrar',
      'register': 'Registrarse',
      'no_account': '¿No tienes cuenta? Regístrate',
      'have_account': '¿Ya tienes cuenta? Inicia sesión',
      'or': 'o continúa con',
      'google': 'Continuar con Google',
      'microsoft': 'Continuar con Microsoft',
      'welcome_back': '¡Bienvenido de nuevo!',
      'account_created': 'Cuenta creada correctamente.',
      'generic_error': 'Ocurrió un error',
      'no_internet':
      'No se pudo conectar. Revisa tu conexión a internet e inténtalo de nuevo.',
      'error_invalid_credentials': 'Correo o contraseña incorrectos.',
      'error_invalid_email': 'Introduce un correo válido.',
      'error_email_in_use': 'Ya existe una cuenta con ese correo.',
      'error_weak_password':
      'La contraseña es muy débil. Usa al menos 6 caracteres.',
      'error_too_many_requests':
      'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
      'error_internal':
      'No pudimos completar el acceso. Revisa tu conexión e inténtalo nuevamente.',
      'empty_credentials': 'Introduce las credenciales de tu cuenta.',
      'empty_email': 'Introduce tu correo.',
      'invalid_email_format': 'Introduce un correo válido.',
      'empty_password': 'Introduce tu contraseña.',
      'invalid_password': 'Contraseña inválida.',
      'short_password': 'La contraseña debe tener al menos 6 caracteres.',
      'error_account_exists_different_credential':
      'Ya existe una cuenta con este correo. Inicia sesión con el método que utilizaste originalmente.',
      'error_user_disabled': 'Esta cuenta fue deshabilitada.',
      'forgot_password': '¿Olvidaste tu contraseña?',
    },
    AppLanguage.en: {
      'tagline': 'Best Planner',
      'login_title': 'Log in',
      'signup_title': 'Create account',
      'email': 'School or personal email',
      'password_login': 'Password',
      'password_signup': 'Password, min. 6 characters',
      'enter': 'Log in',
      'register': 'Sign up',
      'no_account': "Don't have an account? Sign up",
      'have_account': 'Already have an account? Log in',
      'or': 'or continue with',
      'google': 'Continue with Google',
      'microsoft': 'Continue with Microsoft',
      'welcome_back': 'Welcome back!',
      'account_created': 'Account created successfully.',
      'generic_error': 'Something went wrong',
      'no_internet':
      "Couldn't connect. Check your internet connection and try again.",
      'error_invalid_credentials': 'Incorrect email or password.',
      'error_invalid_email': 'Enter a valid email.',
      'error_email_in_use': 'An account with that email already exists.',
      'error_weak_password':
      'Password is too weak. Use at least 6 characters.',
      'error_too_many_requests':
      'Too many attempts. Please wait a moment and try again.',
      'error_internal':
      "We couldn't complete your login. Check your connection and try again.",
      'empty_credentials': 'Enter your account credentials.',
      'empty_email': 'Enter your email.',
      'invalid_email_format': 'Enter a valid email.',
      'empty_password': 'Enter your password.',
      'invalid_password': 'Invalid password.',
      'short_password': 'Password must be at least 6 characters.',
      'error_account_exists_different_credential':
      'An account already exists with this email. Sign in with the method you originally used.',
      'error_user_disabled': 'This account has been disabled.',
      'forgot_password': 'Forgot your password?',
    },
  };

  static String t(AppLanguage lang, String key) =>
      _values[lang]?[key] ?? key;
}

/// -----------------------------------------------------------------------
/// LoginScreen
/// -----------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with WidgetsBindingObserver {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final FocusNode _passwordFocusNode = FocusNode();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  AppLanguage _lang = AppLanguage.es;

  bool _isMicrosoftAuthInProgress = false;
  bool _microsoftFlowLeftApp = false;
  int _microsoftAttemptId = 0;

  String _t(String key) => _Strings.t(_lang, key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No se requiere manejo especial para el flujo de verificación.
  }

  String _friendlyAuthError(Object error) {
    if (error is TimeoutException) {
      return _t('no_internet');
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
          return _t('no_internet');
        case 'invalid-email':
          return _t('error_invalid_email');
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return _t('error_invalid_credentials');
        case 'email-already-in-use':
          return _t('error_email_in_use');
        case 'weak-password':
          return _t('error_weak_password');
        case 'too-many-requests':
          return _t('error_too_many_requests');
        case 'internal-error':
          return _t('error_internal');
        case 'user-disabled':
          return _t('error_user_disabled');
        case 'account-exists-with-different-credential':
          return _t('error_account_exists_different_credential');
        case 'canceled':
        case 'cancelled':
        case 'user-cancelled':
        case 'web-context-canceled':
        case 'web-context-cancelled':
        case 'popup-closed-by-user':
          return '';
        default:
          return _t('generic_error');
      }
    }
    return _t('generic_error');
  }

  String? _validateFields() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty && password.isEmpty) {
      return _t('empty_credentials');
    }

    if (email.isEmpty) {
      return _t('empty_email');
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return _t('invalid_email_format');
    }

    if (password.isEmpty) {
      return _t('empty_password');
    }

    if (_isLogin) {
      if (password.length < 6) {
        return _t('invalid_password');
      }
    } else {
      if (password.length < 6) {
        return _t('short_password');
      }
    }

    return null;
  }

  // --------------------------- AUTENTICACIÓN ---------------------------

  Future<void> _authenticate() async {
    if (_isLoading) return;

    final validationError = _validateFields();
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        final userCredential = await _auth
            .signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        )
            .timeout(const Duration(seconds: 6));

        final user = userCredential.user;
        if (user == null) {
          if (!mounted) return;
          _showMessage(_t('generic_error'));
          return;
        }

        await user.reload();

        if (!mounted) return;

        final refreshedUser = _auth.currentUser;

        if (refreshedUser != null && !refreshedUser.emailVerified) {
          return;
        }

        _showMessage(_t('welcome_back'));
      } else {
        final userCredential = await _auth
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        )
            .timeout(const Duration(seconds: 6));

        final user = userCredential.user;
        if (user == null) {
          if (!mounted) return;
          _showMessage(_t('generic_error'));
          return;
        }

        await FirebaseAuth.instance.setLanguageCode(
          _lang == AppLanguage.en ? 'en' : 'es',
        );
        await user.sendEmailVerification();

        if (!mounted) return;
      }
    } catch (e) {
      debugPrint('Auth error: $e');
      if (!mounted) return;
      _showMessage(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final googleUser =
      await _googleSignIn.signIn().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 15));

      final isNewUser =
          userCredential.additionalUserInfo?.isNewUser ?? false;

      if (!mounted) return;
      _showMessage(
        isNewUser ? _t('account_created') : _t('welcome_back'),
      );
    } catch (e) {
      debugPrint('Auth error: $e');
      if (!mounted) return;
      _showMessage(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithMicrosoft() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final attemptId = ++_microsoftAttemptId;
    _isMicrosoftAuthInProgress = true;
    _microsoftFlowLeftApp = false;

    try {
      final provider = MicrosoftAuthProvider();

      provider.setCustomParameters({
        'prompt': 'select_account',
        'tenant': 'common',
      });

      final userCredential = await _auth.signInWithProvider(provider);

      final isNewUser =
          userCredential.additionalUserInfo?.isNewUser ?? false;

      if (!mounted) return;
      _showMessage(
        isNewUser ? _t('account_created') : _t('welcome_back'),
      );
    } catch (e) {
      debugPrint('Microsoft Auth error: $e');
      if (!mounted) return;
      final message = _friendlyAuthError(e);
      if (message.isNotEmpty) {
        _showMessage(message);
      }
    } finally {
      if (!mounted) return;
      if (attemptId != _microsoftAttemptId) return;
      _isMicrosoftAuthInProgress = false;
      _microsoftFlowLeftApp = false;
      setState(() => _isLoading = false);
    }
  }

  void _openForgotPassword() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _emailController.text.trim(),
          useEnglish: _lang == AppLanguage.en,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    final palette = AppPalette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppTypography.body(color: palette.surface)),
        backgroundColor: palette.textPrimary,
      ),
    );
  }

  void _toggleLanguage() {
    if (_isLoading) return;
    setState(() {
      _lang = _lang == AppLanguage.es ? AppLanguage.en : AppLanguage.es;
    });
  }

  // ------------------------------ BUILD --------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(palette),
              const SizedBox(height: 24),
              _buildLogoAndName(palette),
              const SizedBox(height: 36),
              _buildAnimatedForm(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const ThemeToggleButton(),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _toggleLanguage,
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.textPrimary,
            backgroundColor: palette.surface,
            side: BorderSide(color: palette.border),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: const Icon(Icons.language, size: 16),
          label: Text(
            _lang == AppLanguage.es ? 'ES' : 'EN',
            style: AppTypography.label(color: palette.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoAndName(AppPalette palette) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset(
              'assets/logo.png',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 32),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BiPi',
                  style: AppTypography.logo(
                      color: palette.textPrimary, size: 28)),
              const SizedBox(height: 2),
              Text(_t('tagline'),
                  style: AppTypography.tagline(
                      color: palette.textMuted, size: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedForm(AppPalette palette) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (child, animation) {
          final childKey = child.key as ValueKey<bool>;
          final isEntering = childKey.value == _isLogin;
          final Offset edgeOffset = isEntering
              ? Offset(_isLogin ? -1.0 : 1.0, 0)
              : Offset(_isLogin ? 1.0 : -1.0, 0);
          final slide =
          Tween<Offset>(begin: edgeOffset, end: Offset.zero)
              .animate(animation);
          return SlideTransition(position: slide, child: child);
        },
        child: Column(
          key: ValueKey<bool>(_isLogin),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isLogin ? _t('login_title') : _t('signup_title'),
              style: AppTypography.screenTitle(color: palette.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              palette: palette,
              controller: _emailController,
              label: _t('email'),
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: _isLoading
                  ? null
                  : (_) => _passwordFocusNode.requestFocus(),
            ),
            const SizedBox(height: 14),
            _buildTextField(
              palette: palette,
              controller: _passwordController,
              label: _isLogin
                  ? _t('password_login')
                  : _t('password_signup'),
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              focusNode: _passwordFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: _isLoading ? null : (_) => _authenticate(),
              suffixIcon: IconButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(
                        () => _obscurePassword = !_obscurePassword),
                icon: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    palette.textMuted,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    _obscurePassword
                        ? 'assets/eye_closed.png'
                        : 'assets/eye_open.png',
                    width: 22,
                    height: 22,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: palette.textMuted,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? Center(
                child: CircularProgressIndicator(
                    color: palette.textPrimary))
                : ElevatedButton(
              onPressed: _authenticate,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primaryAction,
                foregroundColor: palette.onPrimaryAction,
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _isLogin ? _t('enter') : _t('register'),
                style: AppTypography.button(
                    color: palette.onPrimaryAction, size: 16),
              ),
            ),
            const SizedBox(height: 20),
            _buildDivider(palette),
            const SizedBox(height: 20),
            GoogleSignInButton(
              onPressed: _isLoading ? null : _signInWithGoogle,
              label: _t('google'),
            ),
            const SizedBox(height: 12),
            MicrosoftSignInButton(
              onPressed: _isLoading ? null : _signInWithMicrosoft,
              label: _t('microsoft'),
            ),
            const SizedBox(height: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _isLogin = !_isLogin),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    _isLogin ? _t('no_account') : _t('have_account'),
                    style: AppTypography.label(
                      color: palette.textPrimary,
                      size: 14,
                    ),
                  ),
                ),
                if (_isLogin)
                  TextButton(
                    onPressed: _isLoading ? null : _openForgotPassword,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      _t('forgot_password'),
                      style: AppTypography.label(
                        color: palette.textPrimary,
                        size: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required AppPalette palette,
    required TextEditingController controller,
    required String label,
    required bool enabled,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      enabled: enabled,
      style: AppTypography.body(color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.label(color: palette.textMuted),
        filled: true,
        suffixIcon: suffixIcon,
        fillColor: palette.surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: BorderSide(color: palette.textPrimary, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
      ),
    );
  }

  Widget _buildDivider(AppPalette palette) {
    return Row(
      children: [
        Expanded(child: Divider(color: palette.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(_t('or'),
              style: AppTypography.label(color: palette.textMuted)),
        ),
        Expanded(child: Divider(color: palette.border)),
      ],
    );
  }
}