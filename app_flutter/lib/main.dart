import 'package:flutter/material.dart';
import 'views/loginScreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BibliotecaEscolarApp());
}

class BibliotecaEscolarApp extends StatelessWidget {
  const BibliotecaEscolarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biblioteca Pública - Calidad a su servicio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const LoginScreen(),
    );
  }
}
