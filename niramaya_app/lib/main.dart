import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

const _sosChannel = MethodChannel('com.niramaya.app/sos_intent');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientHelper.initialize();

  // Cold-start: check if launched via hardware SOS key
  bool hardwareSosTrigger = false;
  try {
    hardwareSosTrigger =
        await _sosChannel.invokeMethod<bool>('getHardwareFlag') ?? false;
  } catch (_) {}

  runApp(ProviderScope(
    child: NiramayaApp(hardwareSosTrigger: hardwareSosTrigger),
  ));
}

class NiramayaApp extends StatefulWidget {
  final bool hardwareSosTrigger;
  const NiramayaApp({super.key, required this.hardwareSosTrigger});

  @override
  State<NiramayaApp> createState() => _NiramayaAppState();
}

class _NiramayaAppState extends State<NiramayaApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Hot-launch: app already running, side key fires onNewIntent
    _sosChannel.setMethodCallHandler((call) async {
      if (call.method == 'triggerSos') {
        _navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/sos-trigger', (r) => r.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Niramaya',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: widget.hardwareSosTrigger ? '/sos-trigger' : '/',
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
