import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:BiPi/AppColors.dart';
import 'package:BiPi/GoogleSignInButton.dart';

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
      'password': 'Contraseña (mínimo 6 caracteres)',
      'enter': 'Entrar',
      'register': 'Registrarse',
      'no_account': '¿No tienes cuenta? Regístrate',
      'have_account': '¿Ya tienes cuenta? Inicia sesión',
      'or': 'o continúa con',
      'google': 'Continuar con Google',
      'welcome_back': '¡Bienvenido de nuevo!',
      'account_created': '¡Cuenta creada con éxito!',
      'generic_error': 'Ocurrió un error',
      'no_internet': 'No se pudo conectar. Revisa tu conexión a internet e inténtalo de nuevo.',
      'error_invalid_credentials': 'Correo o contraseña incorrectos.',
      'error_invalid_email': 'El correo no tiene un formato válido.',
      'error_email_in_use': 'Ya existe una cuenta con ese correo.',
      'error_weak_password': 'La contraseña es muy débil. Usa al menos 6 caracteres.',
      'error_too_many_requests': 'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
    },
    AppLanguage.en: {
      'tagline': 'Best Planner',
      'login_title': 'Log in',
      'signup_title': 'Create account',
      'email': 'School or personal email',
      'password': 'Password (min. 6 characters)',
      'enter': 'Log in',
      'register': 'Sign up',
      'no_account': "Don't have an account? Sign up",
      'have_account': 'Already have an account? Log in',
      'or': 'or continue with',
      'google': 'Continue with Google',
      'welcome_back': 'Welcome back!',
      'account_created': 'Account created successfully!',
      'generic_error': 'Something went wrong',
      'no_internet': "Couldn't connect. Check your internet connection and try again.",
      'error_invalid_credentials': 'Incorrect email or password.',
      'error_invalid_email': "That email doesn't look valid.",
      'error_email_in_use': 'An account with that email already exists.',
      'error_weak_password': 'Password is too weak. Use at least 6 characters.',
      'error_too_many_requests': 'Too many attempts. Please wait a moment and try again.',
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

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final FocusNode _passwordFocusNode = FocusNode();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  AppLanguage _lang = AppLanguage.es;

  String _t(String key) => _Strings.t(_lang, key);

  /// Traduce errores comunes de Firebase Auth a mensajes claros en el
  /// idioma actual, en vez de mostrar el texto crudo (en inglés) que
  /// devuelve Firebase por defecto.
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
        default:
          return error.message ?? _t('generic_error');
      }
    }
    return _t('generic_error');
  }

  // --------------------------- AUTENTICACIÓN ---------------------------

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _auth
            .signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        )
            .timeout(const Duration(seconds: 15));
        _showMessage(_t('welcome_back'));
        // Eliminada la navegación manual. _AuthGate reaccionará a
        // authStateChanges y mostrará ConsentScreen o HomeScreen.
      } else {
        await _auth
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        )
            .timeout(const Duration(seconds: 15));
        _showMessage(_t('account_created'));
        // Eliminada la navegación manual. _AuthGate reaccionará a
        // authStateChanges y mostrará ConsentScreen.
      }
    } catch (e) {
      _showMessage(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser =
      await _googleSignIn.signIn().timeout(const Duration(seconds: 15));
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 15));
      _showMessage(_t('welcome_back'));
      // Eliminada la navegación manual. _AuthGate reaccionará a
      // authStateChanges.
    } catch (e) {
      _showMessage(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    final palette = AppPalette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppTypography.body(color: palette.surface)),
        backgroundColor: AppColors.deepBlue,
      ),
    );
  }

  void _toggleLanguage() {
    setState(() {
      _lang = _lang == AppLanguage.es ? AppLanguage.en : AppLanguage.es;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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

  /// Selector de idioma como botón real (pill con borde), no un TextButton
  /// suelto — se lee como una acción deliberada, no como un ícono perdido.
  Widget _buildTopBar(AppPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: _toggleLanguage,
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

  /// Logo real + "BiPi" (Sanchez) + tagline "Best Planner" (Sanchez
  /// itálica). Horizontal: logo a la izquierda, texto a la izquierda.
  /// El logo va en tarjeta blanca con sombra para aislarlo del fondo.
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
                  color: Colors.black.withOpacity(0.08),
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
              Text('BiPi', style: AppTypography.logo(color: palette.textPrimary, size: 28)),
              const SizedBox(height: 2),
              Text(_t('tagline'),
                  style: AppTypography.tagline(color: palette.textMuted, size: 13)),
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

          final slide = Tween<Offset>(
            begin: edgeOffset,
            end: Offset.zero,
          ).animate(animation);

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
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
            ),
            const SizedBox(height: 14),
            _buildTextField(
              palette: palette,
              controller: _passwordController,
              label: _t('password'),
              obscureText: _obscurePassword,
              focusNode: _passwordFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _authenticate(),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
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
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
              child: CircularProgressIndicator(color: palette.textPrimary),
            )
                : ElevatedButton(
              onPressed: _authenticate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.deepBlue,
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _isLogin ? _t('enter') : _t('register'),
                style: AppTypography.button(color: AppColors.deepBlue, size: 16),
              ),
            ),
            const SizedBox(height: 20),
            _buildDivider(palette),
            const SizedBox(height: 20),
            GoogleSignInButton(
              onPressed: _isLoading ? null : _signInWithGoogle,
              label: _t('google'),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin ? _t('no_account') : _t('have_account'),
                  style: AppTypography.label(color: palette.textPrimary, size: 14),
                ),
              ),
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
      style: AppTypography.body(color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.label(color: palette.textMuted),
        filled: true,
        suffixIcon: suffixIcon,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      ),
    );
  }

  Widget _buildDivider(AppPalette palette) {
    return Row(
      children: [
        Expanded(child: Divider(color: palette.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(_t('or'), style: AppTypography.label(color: palette.textMuted)),
        ),
        Expanded(child: Divider(color: palette.border)),
      ],
    );
  }
}