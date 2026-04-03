// ── Splash Screen — Session check + branding ────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(AppConstants.splashDuration);

    if (!mounted) return;

    // Check existing session
    await ref.read(authProvider.notifier).checkSession();

    if (!mounted) return;

    final authState = ref.read(authProvider);

    switch (authState.status) {
      case AuthStatus.authenticated:
        Navigator.of(context).pushReplacementNamed('/home');
        break;
      case AuthStatus.pendingVerification:
        Navigator.of(context).pushReplacementNamed('/pending-verification');
        break;
      default:
        Navigator.of(context).pushReplacementNamed('/login');
        break;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing teal circle with ambulance icon
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // App title
            Text(
              'NIRAMAYA',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    fontSize: 32,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'DRIVER',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                  ),
            ),
            const SizedBox(height: 48),

            // Loading indicator
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
