import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_page.dart';
import 'screens/main_page.dart';
import 'utils/app_colors.dart';

import 'package:safl/services/notification_service.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint("Notification Init Error: $e");
    }
    
    runApp(const MyApp());
  } catch (e) {
    debugPrint("Main Error: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> checkLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_logged_in') ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAFL BUSINESS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: bodyBg,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue, surface: bodyBg),
        useMaterial3: true,
        fontFamily: '.SF Pro Text', // Native iOS font feel
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(color: textHeading, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: FutureBuilder<bool>(
        future: checkLogin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: primaryBlue)),
            );
          }

          return snapshot.data == true
              ? const MainPage()
              : const LoginPage();
        },
      ),
    );
  }
}
