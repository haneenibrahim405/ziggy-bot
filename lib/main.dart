import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/control_screen.dart';

void main() {
  runApp(ZiggyBotApp());
}

class ZiggyBotApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ziggy Bot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF231A4E),
      ),
      initialRoute: "/",
      routes: {
        "/": (context) => SplashScreen(),
        "/upload": (context) => UploadScreen(),
        "/control": (context) => ControlScreen(),
      },
    );
  }
}
