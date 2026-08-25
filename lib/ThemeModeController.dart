import 'package:flutter/material.dart';

/// Única fuente de verdad para el modo de tema.
/// Se mantiene en memoria durante la sesión; no persiste al reiniciar.
final ValueNotifier<ThemeMode> themeModeNotifier =
ValueNotifier<ThemeMode>(ThemeMode.system);