import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'data/supabase_client.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/dispatch_tracking_screen.dart';
import 'screens/sos_trigger_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseClientHelper.initialize();

  runApp(const ProviderScope(child: NiramayaApp()));
}

class NiramayaApp extends StatelessWidget {
  const NiramayaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Niramaya',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/otp': (context) => const OtpScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/consent': (context) => const ConsentScreen(),
        '/dispatch': (context) => const DispatchTrackingScreen(),
        '/sos-trigger': (context) => const SosTriggerScreen(),
      },
    );
  }
}
