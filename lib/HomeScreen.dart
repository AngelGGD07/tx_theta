import 'package:flutter/material.dart';
import 'package:BiPi/CaptureResponsibilityScreen.dart';

import 'Responsibility.dart';
import 'ResponsibilityCard.dart';
import 'ResponsibilityService.dart';
import 'VerificationNotificationService.dart';
import 'main.dart';
import 'AppColors.dart';
import 'ThemeToggleButton.dart';
import 'AccountScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = ResponsibilityService();

  bool _isProcessingNotificationAction = false;
  int _selectedIndex = 0;

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

    pendingNotificationAction.value = null;

    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
    }

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
    } on DiscardedResponsibilityException {
      _consumeDiscardedAction();
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
    try {
      await _service.ensureResponsibilityActive(action.responsibilityId);
    } on DiscardedResponsibilityException {
      _consumeDiscardedAction();
      return;
    }

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
    try {
      await _service.ensureResponsibilityActive(action.responsibilityId);
    } on DiscardedResponsibilityException {
      _consumeDiscardedAction();
      return;
    }

    await _service.recordNotYetResponse(
      responsibilityId: action.responsibilityId,
    );

    await _service.logNotificationEvent(
      responsibilityId: action.responsibilityId,
      type: 'notification_action_selected',
      actionSelected: action.actionId,
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
  }

  void _consumeDiscardedAction() {
    rootScaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Esta observación ya fue descartada.'),
        ),
      );
  }

  void _onInicioSelected() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _onNuevaPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CaptureResponsibilityScreen(),
      ),
    );
  }

  void _onCuentaSelected() {
    setState(() {
      _selectedIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex == 2) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'BiPi',
            style: AppTypography.logo(
              color: palette.textPrimary,
              size: 24,
            ),
          ),
          actions: const [
            ThemeToggleButton(),
          ],
        ),
        body: _selectedIndex == 0
            ? StreamBuilder<List<Responsibility>>(
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
                    style:
                    AppTypography.body(color: palette.destructive),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            } else {
              items = snapshot.data ?? [];
              if (items.isEmpty) {
                body = const _EmptyState();
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

            return body;
          },
        )
            : const AccountScreen(),
        bottomNavigationBar: _BiPiBottomBar(
          selectedIndex: _selectedIndex,
          onInicioSelected: _onInicioSelected,
          onNuevaPressed: _onNuevaPressed,
          onCuentaSelected: _onCuentaSelected,
        ),
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
              'Pon a prueba tus decisiones',
              textAlign: TextAlign.center,
              style: AppTypography.screenTitle(
                color: palette.textPrimary,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra una responsabilidad para contrastar tu intención '
                  'con tu inicio real.',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                color: palette.textSecondary,
                size: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BiPiBottomBar extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onInicioSelected;
  final VoidCallback onNuevaPressed;
  final VoidCallback onCuentaSelected;

  const _BiPiBottomBar({
    required this.selectedIndex,
    required this.onInicioSelected,
    required this.onNuevaPressed,
    required this.onCuentaSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _BottomBarItem(
                    label: 'Inicio',
                    icon: Icons.home_outlined,
                    selected: selectedIndex == 0,
                    onTap: onInicioSelected,
                  ),
                ),
                Expanded(
                  child: _BottomBarCenterAction(
                    onTap: onNuevaPressed,
                  ),
                ),
                Expanded(
                  child: _BottomBarItem(
                    label: 'Cuenta',
                    icon: Icons.person_outline,
                    selected: selectedIndex == 2,
                    onTap: onCuentaSelected,
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

class _BottomBarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _BottomBarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? palette.surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? palette.textPrimary : palette.textMuted,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.label(
                  color: selected ? palette.textPrimary : palette.textMuted,
                  size: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBarCenterAction extends StatelessWidget {
  final VoidCallback onTap;

  const _BottomBarCenterAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Semantics(
      button: true,
      label: 'Nueva responsabilidad',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: palette.primaryAction,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: 20,
                color: palette.onPrimaryAction,
              ),
              const SizedBox(height: 2),
              Text(
                'Nueva',
                style: AppTypography.label(
                  color: palette.onPrimaryAction,
                  size: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}