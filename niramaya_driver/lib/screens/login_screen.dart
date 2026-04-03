// ── Login Screen — Staff ID + Phone login ───────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _staffIdController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _staffIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _demoFill() {
    _staffIdController.text = AppConstants.demoStaffId;
    _phoneController.text = AppConstants.demoPhone;
    setState(() {});
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final profile = await ref.read(authProvider.notifier).login(
          _staffIdController.text.trim(),
          _phoneController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    final authState = ref.read(authProvider);

    if (profile != null) {
      if (!profile.isVerified) {
        Navigator.of(context).pushReplacementNamed('/pending-verification');
      } else {
        Navigator.of(context).pushNamed('/otp', arguments: profile);
      }
    } else if (authState.status == AuthStatus.error) {
      _showError(authState.errorMessage ?? 'Login failed');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // Header
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'NIRAMAYA DRIVER',
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.primary,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w800,
                            ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Sign in to your staff account',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Staff ID field
                Text(
                  'STAFF ID',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _staffIdController,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'DEMO-DRV-001',
                    prefixIcon: Icon(Icons.badge, color: AppColors.textMuted),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Staff ID required' : null,
                ),
                const SizedBox(height: 24),

                // Phone field
                Text(
                  'PHONE NUMBER',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    hintText: '+91 98765 43210',
                    prefixIcon: Icon(Icons.phone, color: AppColors.textMuted),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Phone required' : null,
                ),
                const SizedBox(height: 16),

                // Demo fill chip
                Center(
                  child: ActionChip(
                    label: const Text('Demo Fill'),
                    avatar: const Icon(
                      Icons.auto_fix_high,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    labelStyle: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                    onPressed: _demoFill,
                  ),
                ),
                const SizedBox(height: 32),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'CONTINUE',
                            style: TextStyle(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Register link
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/register');
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'New to Niramaya? ',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Register as Driver',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
