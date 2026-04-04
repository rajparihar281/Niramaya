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
    with TickerProviderStateMixin {
  late AnimationController _ring1Controller;
  late AnimationController _ring2Controller;
  late AnimationController _ring3Controller;
  late AnimationController _textController;

  late Animation<double> _ring1;
  late Animation<double> _ring2;
  late Animation<double> _ring3;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _ring1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _ring2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _ring3Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _ring1 = Tween<double>(begin: 0.82, end: 1.1).animate(
      CurvedAnimation(parent: _ring1Controller, curve: Curves.easeInOut),
    );
    _ring2 = Tween<double>(begin: 0.72, end: 1.02).animate(
      CurvedAnimation(parent: _ring2Controller, curve: Curves.easeInOut),
    );
    _ring3 = Tween<double>(begin: 0.62, end: 0.92).animate(
      CurvedAnimation(parent: _ring3Controller, curve: Curves.easeInOut),
    );
    _textOpacity = CurvedAnimation(parent: _textController, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(AppConstants.splashDuration);
    if (!mounted) return;

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
    _ring1Controller.dispose();
    _ring2Controller.dispose();
    _ring3Controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF0D1B2E), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Tri-ring pulsing ambulance icon
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _ring3,
                      builder: (ctx, child) => Transform.scale(
                        scale: _ring3.value,
                        child: Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.07),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _ring2,
                      builder: (_, __) => Transform.scale(
                        scale: _ring2.value,
                        child: Container(
                          width: 165,
                          height: 165,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _ring1,
                      builder: (_, __) => Transform.scale(
                        scale: _ring1.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.07),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 32,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Core icon with gradient
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C6AE), Color(0xFF0EA5E9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Staggered text reveal
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      Text(
                        'NIRAMAYA',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 7,
                              fontSize: 32,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'DRIVER',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 10,
                              fontWeight: FontWeight.w400,
                              fontSize: 15,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Niramaya-Net · Staff Portal',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
