import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'firebase_options.dart';
import 'AppColors.dart';
import 'LoginScreen.dart';
import 'HomeScreen.dart';
import 'ResponsibilityService.dart';
import 'VerificationNotificationService.dart';
import 'Responsibility.dart' show StartSource;

/// Contexto normalizado de una acción de notificación que necesita
/// interacción del usuario (elegir fecha, ver la responsabilidad) y por
/// tanto no puede resolverse aquí. HomeScreen la lee al montar y la limpia.
/// main.dart NO decide cómo se presenta — solo la transporta.
class PendingNotificationAction {
  final String actionId;
  final String responsibilityId;

  PendingNotificationAction({
    required this.actionId,
    required this.responsibilityId,
  });
}

PendingNotificationAction? pendingNotificationAction;

final _notificationService = VerificationNotificationService();
final _responsibilityService = ResponsibilityService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  tz_data.initializeTimeZones();

  await _notificationService.init(onAction: _handleNotificationAction);

  runApp(const MyApp());
}

/// Manejador de acciones de notificación. Normaliza la entrada, registra
/// que la acción llegó, y delega la escritura de dominio al servicio.
/// No contiene diálogos ni decide presentación — eso es de la UI.
Future<void> _handleNotificationAction(
    String responsibilityId,
    String actionId,
    ) async {
  if (responsibilityId.isEmpty) {
    debugPrint('Acción de notificación sin responsibilityId: $actionId');
    return;
  }

  // Se registra primero, siempre — así distinguimos "no llegó" de
  // "llegó pero no se procesó", tal como exige el plan de validación.
  await _responsibilityService.logNotificationEvent(
    responsibilityId: responsibilityId,
    type: 'notification_action_received',
    actionSelected: actionId,
  );

  switch (actionId) {
    case VerificationAction.starting:
    // Ruta de mayor calidad de señal. Idempotente: si ya existe un
    // inicio registrado, no lo sobrescribe (ver ResponsibilityService).
      await _responsibilityService.markStartedIfNotAlready(
        responsibilityId: responsibilityId,
        actualStartAt: DateTime.now(),
        source: StartSource.reminderLive,
      );
      break;

    case VerificationAction.alreadyStarted:
    case VerificationAction.notYet:
    // Estas necesitan interacción del usuario (selector de fecha, o
    // simplemente abrir la responsabilidad). Se resuelven en HomeScreen,
    // no aquí. Deliberadamente NO implementadas todavía — el plan de
    // validación dice: primero cierra notification_live end-to-end.
      pendingNotificationAction = PendingNotificationAction(
        actionId: actionId,
        responsibilityId: responsibilityId,
      );
      break;

    default:
      debugPrint('Acción de notificación desconocida: $actionId');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiPi',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const _AuthGate(),
    );
  }
}

/// Decide Login vs Home según la sesión de Firebase Auth.
/// Solo enrutamiento — cero lógica de dominio.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}