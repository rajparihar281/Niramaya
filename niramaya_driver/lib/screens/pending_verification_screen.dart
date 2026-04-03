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
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start polling every 30s
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
          .from('staff_users')
          .select('is_verified')
          .eq('id', authState.profile!.id)
          .maybeSingle();

      if (result != null && result['is_verified'] == true) {
        _pollTimer?.cancel();
        if (!mounted) return;

        // Navigate to OTP screen
        Navigator.of(context).pushReplacementNamed(
          '/otp',
          arguments: authState.profile,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated clock icon
              FadeTransition(
                opacity: _pulseAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.warning.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.hourglass_top,
                    color: AppColors.warning,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'PENDING VERIFICATION',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                'Your account is under review.',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A hospital admin will verify your driving license and employment status.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Status info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    if (profile != null) ...[
                      _infoRow('Name', profile.fullName ?? '—'),
                      const SizedBox(height: 10),
                      _infoRow('Staff ID', profile.staffId),
                      const SizedBox(height: 10),
                      _infoRow('Status', 'Awaiting verification'),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Checking every 30 seconds...',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Logout button
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (!mounted) return;
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('LOGOUT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
