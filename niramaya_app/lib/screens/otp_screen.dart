import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';

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
  bool _otpAutoFilled = false;
  Timer? _autoFillTimer;

  @override
  void initState() {
    super.initState();
    // Start auto-fill timer (demo behavior)
    _autoFillTimer = Timer(AppConstants.otpAutoFillDelay, _autoFillOtp);
  }

  void _autoFillOtp() {
    if (!mounted) return;
    const otp = AppConstants.demoOtp;
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = otp[i];
    }
    setState(() => _otpAutoFilled = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.auto_fix_high, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text('OTP auto-detected'),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _autoFillTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp =>
      _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final otp = _enteredOtp;
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-digit OTP')),
      );
      return;
    }

    // Demo: accept any 6-digit OTP (in production, verify with backend)
    setState(() => _isVerifying = true);

    final abhaId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
    final success = await ref.read(authProvider.notifier).loginWithAbha(abhaId);

    if (!mounted) return;

    if (success) {
      // Fetch patient record after login
      final userId = ref.read(authProvider).user?.id;
      if (userId != null) {
        await ref.read(patientProvider.notifier).fetchRecord(userId);
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      setState(() => _isVerifying = false);
      final error = ref.read(authProvider).error ?? 'Verification failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.emergency),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final abhaId = ModalRoute.of(context)?.settings.arguments as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // Lock icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify OTP',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'OTP sent to your registered number',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              if (abhaId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'ABHA: $abhaId',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 40),
              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 44,
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              // Verify button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify'),
                ),
              ),
              const SizedBox(height: 16),
              if (_otpAutoFilled)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'OTP auto-detected',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
