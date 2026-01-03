import 'package:flutter/material.dart';
import 'config/router.dart';

void main() {
  runApp(MyApp()); // ❌ jangan pakai const
}

class MyApp extends StatelessWidget { 
  MyApp({super.key}); // ❌ jangan const

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Porto DB',

      // GoRouter (Splash -> Home -> Detail)
      routerConfig: router,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          shape: CircleBorder(),
        ),
      ),
    );
  }
}
