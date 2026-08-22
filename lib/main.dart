import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'firebase_options.dart';
import 'AnalyticsService.dart';
import 'AppColors.dart';
import 'LoginScreen.dart';
import 'HomeScreen.dart';
import 'ResponsibilityService.dart';
import 'VerificationNotificationService.dart';
import 'Responsibility.dart' show StartSource;

// 1. LA LLAVE MÁGICA: Controla los mensajes en pantalla (SnackBar) desde CUALQUIER archivo
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PendingNotificationAction {
  final String actionId;
  final String responsibilityId;

  PendingNotificationAction({
    required this.actionId,
    required this.responsibilityId,
  });
}

final pendingNotificationAction = ValueNotifier<PendingNotificationAction?>(null);

final _notificationService = VerificationNotificationService();
final _responsibilityService = ResponsibilityService();
final _analytics = AnalyticsService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  tz_data.initializeTimeZones();

  await _notificationService.init(onAction: _handleNotificationAction);

  runApp(const MyApp());
}

Future<void> _handleNotificationAction(
    String responsibilityId,
    String actionId,
    ) async {
  if (responsibilityId.isEmpty) return;

  await _responsibilityService.logNotificationEvent(
    responsibilityId: responsibilityId,
    type: 'notification_action_received',
    actionSelected: actionId,
  );

  await _analytics.logEvent(
    AnalyticsEvents.notificationActionReceived,
    parameters: {
      AnalyticsParams.responsibilityId: responsibilityId,
      AnalyticsParams.actionId: actionId,
    },
  );

  switch (actionId) {
    case VerificationAction.starting:
    // CASO A: Acción directa ("Estoy empezando"). Se salta el menú.
      await _responsibilityService.markStartedIfNotAlready(
        responsibilityId: responsibilityId,
        actualStartAt: DateTime.now(),
        source: StartSource.reminderLive,
      );
      _showGlobalUndo(responsibilityId);
      break;

    case VerificationAction.alreadyStarted:
    case VerificationAction.notYet:
    // CASO B: Requiere menú ("Ya había empezado"). Pasa a HomeScreen.
      pendingNotificationAction.value = PendingNotificationAction(
        actionId: actionId,
        responsibilityId: responsibilityId,
      );
      break;
  }
}

// 2. LA FUNCIÓN QUE LANZA EL DESHACER BLINDADO
void _showGlobalUndo(String responsibilityId) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Inicio registrado'),
        duration: const Duration(seconds: 6),
        persist: false,
        action: SnackBarAction(
          label: 'DESHACER',
          onPressed: () => _responsibilityService.undoStart(responsibilityId),
        ),
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 3. CONECTAMOS LA LLAVE A LA RAÍZ DE LA APP
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'BiPi',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const _AuthGate(),
    );
  }
}

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
          _analytics.setUser(snapshot.data!.uid);
          return const HomeScreen();
        }
        _analytics.setUser(null);
        return const LoginScreen();
      },
    );
  }
}