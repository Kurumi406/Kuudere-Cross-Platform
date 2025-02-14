import 'package:flutter/material.dart';
import 'package:kuudere/services/notification.dart';
import 'package:kuudere/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Add this line
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF141217),
      ),
      home: SplashScreen(),
    );
  }
}
