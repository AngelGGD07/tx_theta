import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'AnalyticsService.dart';
import 'AppColors.dart';
import 'LoginScreen.dart';
import 'HomeScreen.dart';
import 'ResponsibilityService.dart';
import 'VerificationNotificationService.dart';
import 'Responsibility.dart' show ResponsibilityStatus, StartSource;
import 'ConsentScreen.dart';
import 'ConsentService.dart';
import 'ThemeModeController.dart';
import 'EmailVerificationScreen.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PendingNotificationAction {
  final String actionId;
  final String responsibilityId;

  PendingNotificationAction({
    required this.actionId,
    required this.responsibilityId,
  });
}

final pendingNotificationAction =
ValueNotifier<PendingNotificationAction?>(null);

final _notificationService = VerificationNotificationService();
final _responsibilityService = ResponsibilityService();
final _analytics = AnalyticsService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemeModeController.load();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  tz_data.initializeTimeZones();

  await _notificationService.init(onAction: _handleNotificationAction);

  runApp(const MyApp());
}

Future<void> _handleNotificationAction(
    String responsibilityId, String actionId) async {
  if (responsibilityId.isEmpty) return;

  unawaited(
    _responsibilityService.logNotificationEvent(
      responsibilityId: responsibilityId,
      type: 'notification_action_received',
      actionSelected: actionId,
    ).catchError((Object error) {
      debugPrint('Telemetry error: ${error.runtimeType}');
    }),
  );

  unawaited(
    _analytics.logEvent(
      AnalyticsEvents.notificationActionReceived,
      parameters: {
        AnalyticsParams.responsibilityId: responsibilityId,
        AnalyticsParams.actionId: actionId,
      },
    ).catchError((Object error) {
      debugPrint('Analytics telemetry error: ${error.runtimeType}');
    }),
  );

  unawaited(
    _analytics.logEvent(
      AnalyticsEvents.notificationActionSelected,
      parameters: {
        AnalyticsParams.responsibilityId: responsibilityId,
        AnalyticsParams.actionId: actionId,
      },
    ).catchError((Object error) {
      debugPrint('Analytics telemetry error: ${error.runtimeType}');
    }),
  );

  switch (actionId) {
    case VerificationAction.starting:
      try {
        final responsibility =
        await _responsibilityService.getCachedResponsibility(
          responsibilityId,
        );

        if (responsibility == null) {
          rootScaffoldMessengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'No fue posible encontrar esta responsabilidad en el dispositivo. '
                      'Conéctate a Internet e inténtalo nuevamente.',
                ),
              ),
            );
          break;
        }

        if (responsibility.status != ResponsibilityStatus.pending ||
            responsibility.startedAt != null ||
            responsibility.activeStartEventId != null) {
          rootScaffoldMessengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Ya registraste el inicio de esta responsabilidad.'),
              ),
            );
          break;
        }

        final startEventId = await _responsibilityService.markStartedIfNotAlready(
          responsibilityId: responsibilityId,
          actualStartAt: DateTime.now(),
          source: StartSource.reminderLive,
        );

        if (startEventId != null) {
          unawaited(
            _notificationService
                .cancelVerification(responsibilityId)
                .catchError((Object error) {
              debugPrint('Cancel notification error: ${error.runtimeType}');
            }),
          );

          _showGlobalUndo(
            responsibilityId,
            activeStartEventId: startEventId,
          );
        }
      } on DiscardedResponsibilityException {
        _showDiscardedMessage();
      } catch (e) {
        debugPrint('Start from notification error: ${e.runtimeType}');
      }
      break;

    case VerificationAction.alreadyStarted:
    case VerificationAction.notYet:
      pendingNotificationAction.value = PendingNotificationAction(
        actionId: actionId,
        responsibilityId: responsibilityId,
      );
      break;
  }
}

void _showDiscardedMessage() {
  rootScaffoldMessengerKey.currentState?.showSnackBar(
    const SnackBar(
      content: Text('Esta responsabilidad ya fue descartada.'),
    ),
  );
}

void _showGlobalUndo(
    String responsibilityId, {
      required String activeStartEventId,
    }) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Inicio registrado'),
        duration: const Duration(seconds: 6),
        persist: false,
        action: SnackBarAction(
          label: 'DESHACER',
          onPressed: () {
            unawaited(
              _responsibilityService.undoStart(
                responsibilityId,
                activeStartEventId: activeStartEventId,
              ).catchError((Object error) {
                debugPrint('Undo error: ${error.runtimeType}');
              }),
            );
          },
        ),
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          title: 'BiPi',
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: themeMode,
          home: const _AuthGate(),
        );
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final ConsentService _consentService = ConsentService();

  int _consentRetryCount = 0;
  String? _consentStreamUserId;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _consentStream;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _streamForConsent(
      String userId,
      ) {
    if (_consentStream == null || _consentStreamUserId != userId) {
      _consentStreamUserId = userId;
      _consentStream = _consentService.watchConsent(userId);
    }

    return _consentStream!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          _consentStreamUserId = null;
          _consentStream = null;
          _analytics.setUser(null);
          return const LoginScreen();
        }

        _analytics.setUser(user.uid);

        final requiresPasswordVerification =
        user.providerData.any((info) => info.providerId == 'password');

        if (requiresPasswordVerification && !user.emailVerified) {
          return const EmailVerificationScreen();
        }

        return _buildConsentGate(user.uid);
      },
    );
  }

  Widget _buildConsentGate(String userId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey('consent_${userId}_$_consentRetryCount'),
      stream: _streamForConsent(userId),
      builder: (context, consentSnapshot) {
        if (consentSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (consentSnapshot.hasError) {
          return _ConsentError(
            onRetry: () {
              setState(() {
                _consentStreamUserId = null;
                _consentStream = null;
                _consentRetryCount++;
              });
            },
          );
        }

        if (_consentService.hasValidConsent(consentSnapshot.data)) {
          return const HomeScreen();
        }

        return const ConsentScreen();
      },
    );
  }
}

class _ConsentError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ConsentError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 48, color: palette.textMuted),
                const SizedBox(height: 16),
                Text(
                  'No se pudo verificar el consentimiento.',
                  style: AppTypography.body(color: palette.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Revisa tu conexión a internet e inténtalo de nuevo.',
                  style: AppTypography.label(color: palette.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primaryAction,
                    foregroundColor: palette.onPrimaryAction,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}