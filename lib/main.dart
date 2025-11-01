import 'package:flutter/material.dart';
import 'screens/instructions_screen.dart';
import 'services/ml_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize ML model
  await MLService.initialize();
  
  runApp(const PesoCheckApp());
}

class PesoCheckApp extends StatelessWidget {
  const PesoCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PesoCheck',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF222222),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF222222),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF222222),
          selectedItemColor: Colors.deepPurpleAccent,
          unselectedItemColor: Colors.white70,
        ),
      ),
  // Show instructions first when the app opens
  home: const InstructionsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
