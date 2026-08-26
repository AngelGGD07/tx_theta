import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'AppColors.dart';
import 'ConsentService.dart';
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
              _buildSection(
                palette,
                'Propósito',
                'BiPi es una herramienta experimental para estudiantes universitarios. '
                    'Compara el momento en que una persona cree que empezará una responsabilidad académica '
                    'con el momento en que registra que comenzó.',
              ),
              _buildSection(
                palette,
                'Duración',
                'Una vez iniciado el piloto, tendrá una duración prevista de 14 días.',
              ),
              _buildSection(
                palette,
                'Datos asociados a tu cuenta',
                'La aplicación usa Firebase Auth, que asigna un identificador interno de usuario. '
                    'Los datos no son anónimos: quedan asociados a ese identificador.\n\n'
                    'En Firestore se almacenan datos operativos como tipo de responsabilidad, '
                    'nombre o descripción, fechas, predicción de inicio, momento de inicio registrado, '
                    'fuente del registro, respuestas a notificaciones y estado.\n\n'
                    'En Firebase Analytics se registran eventos de uso como creación de responsabilidad, '
                    'creación de predicción, programación de notificación, selección de acción, '
                    'persistencia de respuesta, registro de inicio, visualización de confrontación y uso de Deshacer.\n\n'
                    'Firebase Analytics no recibe el nombre libre de la responsabilidad, descripción, correo, '
                    'nombre del participante ni contenido académico completo.',
              ),
              _buildSection(
                palette,
                'Finalidad',
                'Los datos se utilizarán únicamente para operar la aplicación durante el piloto, '
                    'analizar si el flujo funciona y resolver incidencias técnicas.',
              ),
              _buildSection(
                palette,
                'Conservación de datos',
                'Los datos se conservarán durante el piloto y hasta un máximo de 90 días después de su '
                    'finalización.\n\n'
                    'La eliminación de los datos será un procedimiento manual realizado por el responsable '
                    'del piloto. No existe eliminación automática.',
              ),
              _buildSection(
                palette,
                'Voluntariedad, retiro y eliminación',
                'Participar es voluntario. Puedes dejar de usar la aplicación y solicitar formalmente '
                    'tu retiro escribiendo a aggd0001@ce.pucmm.edu.do.\n\n'
                    'Para solicitar la eliminación de datos, escribe desde el mismo correo usado al registrarte. '
                    'La solicitud será atendida en un máximo de 15 días laborables.\n\n'
                    'Retirarte no tendrá consecuencias académicas.',
              ),
              _buildSection(
                palette,
                'Limitaciones',
                'BiPi no diagnostica procrastinación, hábitos, salud mental, rendimiento ni riesgo académico. '
                    'No es un servicio de salud, terapia, asesoría académica ni herramienta de vigilancia.',
              ),
              _buildSection(
                palette,
                'Contacto',
                'Responsable: Ángel Gabriel Guzmán Díaz\n'
                    'Correo: aggd0001@ce.pucmm.edu.do\n'
                    'Contexto: piloto académico independiente desarrollado por un estudiante de PUCMM. '
                    'No implica aprobación institucional salvo autorización explícita.',
              ),
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
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.deepBlue,
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
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.deepBlue,
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

  Widget _buildSection(AppPalette palette, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.label(
              color: palette.textPrimary,
              size: 15,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTypography.body(color: palette.textPrimary, size: 14),
          ),
        ],
      ),
    );
  }
}