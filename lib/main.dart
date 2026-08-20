import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'LoginScreen.dart'; // Importamos la pantalla de login

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Estudiantes',
      theme: ThemeData(primarySwatch: Colors.blue), // Un diseño sencillo para V1
      home: const LoginScreen(), // Nuestra nueva pantalla
    );
  }
}