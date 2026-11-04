import 'package:flutter/material.dart';
import 'screens/pairing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AntigravityMobileApp());
}

class AntigravityMobileApp extends StatelessWidget {
  const AntigravityMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity Mobile Orbit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D2FF),
          secondary: Color(0xFF7928CA),
          surface: Color(0xFF161B22),
        ),
        useMaterial3: true,
      ),
      home: const PairingScreen(),
    );
  }
}
