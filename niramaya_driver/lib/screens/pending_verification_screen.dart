// ── Pending Verification Screen ─────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../services/supabase_service.dart';
import '../providers/auth_provider.dart';

class PendingVerificationScreen extends ConsumerStatefulWidget {
  const PendingVerificationScreen({super.key});

  @override
  ConsumerState<PendingVerificationScreen> createState() =>
      _PendingVerificationScreenState();
}

class _PendingVerificationScreenState
    extends ConsumerState<PendingVerificationScreen>
    with TickerProviderStateMixin {
  Timer? _pollTimer;

  late AnimationController _ring1;
  late AnimationController _ring2;
  late AnimationController _ring3;
  late AnimationController _dotsController;

  late Animation<double> _r1Anim;
  late Animation<double> _r2Anim;
  late Animation<double> _r3Anim;

  @override
  void initState() {
    super.initState();

    _ring1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _ring2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2100))
      ..repeat(reverse: true);
    _ring3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _r1Anim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ring1, curve: Curves.easeInOut),
    );
    _r2Anim = Tween<double>(begin: 0.75, end: 1.05).animate(
      CurvedAnimation(parent: _ring2, curve: Curves.easeInOut),
    );
    _r3Anim = Tween<double>(begin: 0.65, end: 0.95).animate(
      CurvedAnimation(parent: _ring3, curve: Curves.easeInOut),
    );

    _pollTimer = Timer.periodic(
      AppConstants.verificationPollInterval,
      (_) => _checkVerification(),
    );
  }

  Future<void> _checkVerification() async {
    final authState = ref.read(authProvider);
    if (authState.profile == null) return;

    try {
      final result = await SupabaseService.client
          .from('drivers')
          .select('is_verified')
          .eq('id', authState.profile!.id)
          .maybeSingle();

      if (result != null && result['is_verified'] == true) {
        _pollTimer?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/otp', arguments: authState.profile);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ring1.dispose();
    _ring2.dispose();
    _ring3.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0xFF0D1B2E), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Multi-ring hourglass icon
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _r3Anim,
                        builder: (_, __) => Transform.scale(
                          scale: _r3Anim.value,
                          child: Container(
                            width: 195,
                            height: 195,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.07),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _r2Anim,
                        builder: (_, __) => Transform.scale(
                          scale: _r2Anim.value,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _r1Anim,
                        builder: (_, __) => Transform.scale(
                          scale: _r1Anim.value,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.warning.withValues(alpha: 0.06),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.warning.withValues(alpha: 0.25),
                                  blurRadius: 24,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.warning.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          color: AppColors.warning,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'PENDING',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'VERIFICATION',
                  style: TextStyle(
                    color: AppColors.warning.withValues(alpha: 0.6),
                    fontSize: 14,
                    letterSpacing: 5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'A hospital admin will verify your driving license and employment status.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // Info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      if (profile != null) ...[
                        _infoRow(Icons.person_rounded, 'Name', profile.fullName ?? '—', AppColors.textPrimary),
                        const SizedBox(height: 12),
                        _infoRow(Icons.badge_rounded, 'Staff ID', profile.staffId, AppColors.primary),
                        const SizedBox(height: 12),
                        _infoRow(Icons.pending_rounded, 'Status', 'Awaiting review', AppColors.warning),
                        const SizedBox(height: 16),
                      ],
                      // Progress dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _dotsController,
                            builder: (_, __) {
                              return Row(
                                children: List.generate(3, (i) {
                                  final phase = (_dotsController.value * 3 - i).clamp(0.0, 1.0);
                                  final opacity = (phase < 0.5 ? phase * 2 : 2 - phase * 2).clamp(0.2, 1.0);
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary.withValues(alpha: opacity),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Checking every 30 seconds',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Logout button
                OutlinedButton.icon(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await ref.read(authProvider.notifier).logout();
                    nav.pushReplacementNamed('/login');
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('LOGOUT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color == AppColors.textPrimary ? AppColors.textPrimary : color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
