// ── Niramaya Driver — Main Entry Point ──────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'services/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/pending_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.card,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize Supabase
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: NiramayaDriverApp()));
}

class NiramayaDriverApp extends StatelessWidget {
  const NiramayaDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Niramaya Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/otp': (context) => const OtpScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/pending-verification': (context) =>
            const PendingVerificationScreen(),
        '/home': (context) => const HomeScreen(),
        '/map': (context) => const MapScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}
