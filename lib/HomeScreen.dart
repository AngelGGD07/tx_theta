import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:BiPi/CaptureResponsibilityScreen.dart';

import 'Responsibility.dart';
import 'ResponsibilityCard.dart';
import 'ResponsibilityService.dart';
import 'VerificationNotificationService.dart';
import 'main.dart';
import 'AppColors.dart';
import 'ThemeToggleButton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = ResponsibilityService();

  bool _isProcessingNotificationAction = false;

  @override
  void initState() {
    super.initState();

    pendingNotificationAction.addListener(_handlePendingAction);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingAction();
    });
  }

  @override
  void dispose() {
    pendingNotificationAction.removeListener(_handlePendingAction);
    super.dispose();
  }

  void _handlePendingAction() {
    if (_isProcessingNotificationAction) {
      return;
    }

    final action = pendingNotificationAction.value;

    if (action == null) {
      return;
    }

    if (action.actionId != VerificationAction.alreadyStarted &&
        action.actionId != VerificationAction.notYet) {
      return;
    }

    _isProcessingNotificationAction = true;

    // Se consume inmediatamente para impedir que el ValueNotifier,
    // una reconstrucción o un reinicio del listener repitan la acción.
    pendingNotificationAction.value = null;

    _processPendingAction(action);
  }

  Future<void> _processPendingAction(
      PendingNotificationAction action) async {
    try {
      if (action.actionId == VerificationAction.alreadyStarted) {
        await _processAlreadyStarted(action);
        return;
      }

      if (action.actionId == VerificationAction.notYet) {
        await _processNotYet(action);
      }
    } catch (error) {
      rootScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos registrar la respuesta. Inténtalo nuevamente.',
            ),
          ),
        );

      debugPrint(
        'Error procesando acción de notificación '
            '${action.actionId}: $error',
      );
    } finally {
      _isProcessingNotificationAction = false;
    }
  }

  Future<void> _processAlreadyStarted(
      PendingNotificationAction action) async {
    await _service.logNotificationEvent(
      responsibilityId: action.responsibilityId,
      type: 'notification_action_selected',
      actionSelected: action.actionId,
    );

    if (!mounted) {
      return;
    }

    await showPastStartSelector(
      context,
      action.responsibilityId,
      _service,
      StartSource.reminderRecalled,
    );
  }

  Future<void> _processNotYet(
      PendingNotificationAction action) async {
    var phase = 'inicio';

    try {
      phase = 'recordNotYetResponse';
      debugPrint(
        'NOT_YET FASE $phase iniciada. '
            'responsibilityId=${action.responsibilityId}',
      );
      await _service.recordNotYetResponse(
        responsibilityId: action.responsibilityId,
      );
      debugPrint(
        'NOT_YET FASE $phase terminada. '
            'responsibilityId=${action.responsibilityId}',
      );

      phase = 'logNotificationEvent';
      debugPrint(
        'NOT_YET FASE $phase iniciada. '
            'actionId=${action.actionId}',
      );
      await _service.logNotificationEvent(
        responsibilityId: action.responsibilityId,
        type: 'notification_action_selected',
        actionSelected: action.actionId,
      );
      debugPrint(
        'NOT_YET FASE $phase terminada. '
            'actionId=${action.actionId}',
      );

      rootScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Todavía no has comenzado. Conservamos tu predicción.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
    } catch (error) {
      debugPrint('NOT_YET FASE $phase FALLÓ: error=${error.runtimeType}');
      if (error is FirebaseException) {
        debugPrint('NOT_YET FASE $phase código Firebase: ${error.code}');
      }
      debugPrint('NOT_YET FASE $phase mensaje técnico: $error');
      debugPrint(
        'NOT_YET FASE $phase responsibilityId: '
            '${action.responsibilityId}',
      );
      debugPrint('NOT_YET FASE $phase actionId: ${action.actionId}');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return StreamBuilder<List<Responsibility>>(
      stream: _service.watchActiveResponsibilities(),
      builder: (context, snapshot) {
        Widget body;
        List<Responsibility> items = const [];

        if (snapshot.connectionState == ConnectionState.waiting) {
          body = const Center(
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError) {
          debugPrint('Home error: ${snapshot.error}');
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No pudimos cargar tus responsabilidades. '
                    'Revisa tu conexión e inténtalo nuevamente.',
                style: AppTypography.body(color: palette.destructive),
                textAlign: TextAlign.center,
              ),
            ),
          );
        } else {
          items = snapshot.data ?? [];
          if (items.isEmpty) {
            body = _EmptyState(
              onCreate: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                  const CaptureResponsibilityScreen(),
                ),
              ),
            );
          } else {
            body = ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final responsibility = items[index];
                return ResponsibilityCard(
                  key: ValueKey(responsibility.id),
                  responsibility: responsibility,
                  service: _service,
                );
              },
            );
          }
        }

        final showFab = snapshot.hasData &&
            !snapshot.hasError &&
            items.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'BiPi',
              style: AppTypography.logo(
                color: palette.textPrimary,
                size: 24,
              ),
            ),
            actions: [
              const ThemeToggleButton(),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => FirebaseAuth.instance.signOut(),
                tooltip: 'Cerrar sesión',
                color: palette.textPrimary,
              ),
            ],
          ),
          body: body,
          floatingActionButton: showFab
              ? FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                const CaptureResponsibilityScreen(),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Nueva'),
            backgroundColor: palette.primaryAction,
            foregroundColor: palette.onPrimaryAction,
          )
              : null,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: palette.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Todavía no has registrado una responsabilidad.',
              textAlign: TextAlign.center,
              style: AppTypography.screenTitle(
                color: palette.textPrimary,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra una y compara cuándo crees que empezarás '
                  'con cuándo empiezas realmente.',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                color: palette.textSecondary,
                size: 15,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryAction,
                  foregroundColor: palette.onPrimaryAction,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'REGISTRAR PRIMERA RESPONSABILIDAD',
                  textAlign: TextAlign.center,
                  style: AppTypography.button(
                    color: palette.onPrimaryAction,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}