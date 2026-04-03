import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _abhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _displayText = '';

  @override
  void dispose() {
    _abhaController.dispose();
    super.dispose();
  }

  /// Format ABHA ID as XXXX-XXXX-XXXX-XX
  String _formatAbha(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 14; i++) {
      if (i == 4 || i == 8 || i == 12) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  void _onAbhaChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = _formatAbha(digits);
    if (formatted != _displayText) {
      setState(() => _displayText = formatted);
      _abhaController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  String? _validateAbha(String? value) {
    if (value == null || value.isEmpty) return 'ABHA ID is required';
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 14) return 'ABHA ID must be exactly 14 digits';
    return null;
  }

  void _sendOtp() {
    if (_formKey.currentState?.validate() ?? false) {
      final abhaId = _abhaController.text;
      Navigator.pushNamed(context, '/otp', arguments: abhaId);
    }
  }

  void _showGuide() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'How to use Niramaya',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _guideStep('1', 'Enter your 14-digit ABHA Health ID'),
              _guideStep('2', 'Verify with OTP sent to your registered number'),
              _guideStep('3', 'Complete your health profile'),
              _guideStep('4', 'Use SOS button in emergencies — help is dispatched instantly'),
              const SizedBox(height: 16),
              Text(
                'Your ABHA ID is your Ayushman Bharat Health Account identifier. '
                'If you don\'t have one, visit https://abha.abdm.gov.in to create it.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _guideStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Top right guide button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: _showGuide,
                    icon: const Icon(Icons.menu_book_rounded),
                    color: AppColors.accent,
                    tooltip: 'Guide',
                  ),
                ),
                const SizedBox(height: 48),
                // Logo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.local_hospital,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  'Enter your ABHA ID',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your 14-digit Ayushman Bharat Health ID',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                // ABHA Input
                TextFormField(
                  controller: _abhaController,
                  onChanged: _onAbhaChanged,
                  validator: _validateAbha,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                    LengthLimitingTextInputFormatter(17), // 14 digits + 3 hyphens
                  ],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'XXXX-XXXX-XXXX-XX',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 32),
                // Send OTP button
                ElevatedButton(
                  onPressed: _sendOtp,
                  child: const Text('Send OTP'),
                ),
                const SizedBox(height: 24),
                // Footer text
                Text(
                  'By continuing, you agree to share your health data\nfor emergency medical services.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
