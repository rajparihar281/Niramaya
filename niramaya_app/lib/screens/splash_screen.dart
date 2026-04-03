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
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    await Future.delayed(AppConstants.splashDuration);
    if (!mounted) return;

    final isLoggedIn =
        await ref.read(authProvider.notifier).checkPersistentLogin();

    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
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
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            // Pulse ring around medical icon
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 100 * _pulseAnimation.value,
                  height: 100 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: child,
                );
              },
              child: const Center(
                child: Icon(
                  Icons.local_hospital,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'NIRAMAYA',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Emergency Medical Services',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.accent.withValues(alpha: 0.9),
                fontWeight: FontWeight.w400,
                letterSpacing: 1,
              ),
            ),
            const Spacer(flex: 3),
            Text(
              'Government of India',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
