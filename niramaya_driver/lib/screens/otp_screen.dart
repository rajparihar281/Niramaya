// ── OTP Screen — 6-digit mock OTP verification ──────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/driver_profile_model.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  bool _hasError = false;
  DriverProfile? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNodes[0].requestFocus(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is DriverProfile) {
      _profile = args;
    } else {
      _profile = ref.read(authProvider).profile;
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpValue => _controllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    if (_hasError) setState(() => _hasError = false);

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_otpValue.length == 6) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpValue;
    if (otp.length != 6) return;

    setState(() => _isVerifying = true);

    // Mock delay
    await Future.delayed(AppConstants.otpMockDelay);

    if (!mounted) return;

    if (otp == AppConstants.demoOtp) {
      // OTP valid — complete auth
      if (_profile != null) {
        await ref.read(authProvider.notifier).completeAuth(_profile!);
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
    } else {
      setState(() {
        _isVerifying = false;
        _hasError = true;
      });
      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Lock icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'VERIFICATION',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the 6-digit OTP sent to your phone',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (_profile != null) ...[
                const SizedBox(height: 4),
                Text(
                  _profile!.phone ?? '',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 40),

              // OTP input fields
              LayoutBuilder(
                builder: (context, constraints) {
                  final totalGaps = 5 * 8.0 + 16.0; // 5 normal gaps + 1 mid gap
                  final boxSize = (constraints.maxWidth - totalGaps) / 6;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        width: boxSize,
                        height: 56,
                        margin: EdgeInsets.only(
                          left: index == 0 ? 0 : 8,
                          right: index == 2 ? 16 : 0,
                        ),
                        child: TextFormField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          cursorColor: AppColors.primary,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: _hasError
                                ? AppColors.danger.withValues(alpha: 0.15)
                                : AppColors.cardElevated,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _hasError
                                    ? AppColors.danger
                                    : AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _hasError
                                    ? AppColors.danger
                                    : AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _hasError
                                    ? AppColors.danger
                                    : AppColors.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (v) => _onOtpChanged(index, v),
                        ),
                      );
                    }),
                  );
                },
              ),

              if (_hasError) ...[
                const SizedBox(height: 16),
                const Text(
                  'Invalid OTP. Please try again.',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 14,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Demo hint
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.info_outline,
                        color: AppColors.primary, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Demo OTP: 123456',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              if (_isVerifying)
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Verifying...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
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
