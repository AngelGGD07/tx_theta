import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:BiPi/CaptureResponsibilityScreen.dart';

import 'Responsibility.dart';
import 'ResponsibilityCard.dart';
import 'ResponsibilityService.dart';
import 'VerificationNotificationService.dart';
import 'main.dart'; // Contiene rootScaffoldMessengerKey y pendingNotificationAction
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
      PendingNotificationAction action,
      ) async {
    try {
      if (action.actionId == VerificationAction.alreadyStarted) {
        await _processAlreadyStarted(action);
        return;
      }

      if (action.actionId == VerificationAction.notYet) {
        await _processNotYet(action);
      }
    } catch (error) {
      // USAMOS LA LLAVE GLOBAL PARA GARANTIZAR EL MENSAJE DE ERROR
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
      PendingNotificationAction action,
      ) async {
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
      PendingNotificationAction action,
      ) async {
    await _service.recordNotYetResponse(
      responsibilityId: action.responsibilityId,
    );

    await _service.logNotificationEvent(
      responsibilityId: action.responsibilityId,
      type: 'notification_action_selected',
      actionSelected: action.actionId,
    );

    // USAMOS LA LLAVE GLOBAL PARA GARANTIZAR QUE EL SNACKBAR APAREZCA SIEMPRE
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
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('BiPi', style: AppTypography.logo(color: palette.textPrimary, size: 24)),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: StreamBuilder<List<Responsibility>>(
        stream: _service.watchActiveResponsibilities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: AppTypography.body(color: palette.textPrimary),
              ),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const _EmptyState();
          }

          return ListView.builder(
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
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CaptureResponsibilityScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.deepBlue,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
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
              'No tienes responsabilidades registradas todavía.',
              textAlign: TextAlign.center,
              style: AppTypography.body(color: palette.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}