// ── Registration Screen — Single insert into public.drivers ─────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/hospital_model.dart';
import '../services/supabase_service.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _staffIdCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();

  String? _selectedBloodGroup;
  String? _selectedHospitalId;
  bool _termsAccepted = false;
  bool _isLoading = false;
  List<HospitalModel> _hospitals = [];

  late AnimationController _scrollHintController;

  final List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
    _scrollHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fetchHospitals();
  }

  Future<void> _fetchHospitals() async {
    try {
      final result = await SupabaseService.client
          .from('hospitals')
          .select('id, name, address')
          .eq('is_active', true)
          .order('name');
      setState(() {
        _hospitals = (result as List)
            .map((h) => HospitalModel.fromMap(h as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      _showError('You must accept the Terms of Service');
      return;
    }
    if (_selectedHospitalId == null) {
      _showError('Please select a hospital');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.client.from('drivers').insert({
        'staff_id': _staffIdCtrl.text.trim(),
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'license_number': _licenseCtrl.text.trim(),
        'years_experience': int.tryParse(_experienceCtrl.text.trim()) ?? 0,
        'blood_group': _selectedBloodGroup,
        'hospital_id': _selectedHospitalId,
        'role': 'driver',
        'is_verified': false,
        'is_active': true,
        'is_on_duty': false,
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/pending-verification');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Registration failed: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _staffIdCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _licenseCtrl.dispose();
    _experienceCtrl.dispose();
    _scrollHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Text(
            'DRIVER REGISTRATION',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              // Intro card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      AppColors.primary.withValues(alpha: 0.03),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C6AE), Color(0xFF0EA5E9)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Join Niramaya as a verified ambulance driver. Your account will be reviewed by a hospital admin.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Section: Personal
              _sectionHeader('PERSONAL INFORMATION', Icons.person_rounded),
              const SizedBox(height: 14),
              _buildField('Full Name', _nameCtrl, Icons.person_rounded,
                  validator: _required),
              _buildField(
                'Staff ID',
                _staffIdCtrl,
                Icons.badge_rounded,
                validator: _required,
                caps: true,
                hint: 'e.g. DEMO-DRV-001',
              ),
              _buildField(
                'Phone',
                _phoneCtrl,
                Icons.phone_rounded,
                validator: _required,
                keyboard: TextInputType.phone,
              ),
              _buildField(
                'Email',
                _emailCtrl,
                Icons.email_rounded,
                keyboard: TextInputType.emailAddress,
              ),

              const SizedBox(height: 8),

              // Section: Professional
              _sectionHeader('PROFESSIONAL DETAILS', Icons.verified_user_rounded),
              const SizedBox(height: 14),
              _buildField(
                'License Number',
                _licenseCtrl,
                Icons.credit_card_rounded,
                validator: _required,
              ),
              _buildField(
                'Years of Experience',
                _experienceCtrl,
                Icons.timer_rounded,
                keyboard: TextInputType.number,
              ),

              // Blood group dropdown
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBloodGroup,
                  dropdownColor: AppColors.cardElevated,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Blood Group',
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bloodtype_rounded, color: AppColors.danger, size: 17),
                    ),
                  ),
                  items: _bloodGroups
                      .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBloodGroup = v),
                ),
              ),

              // Hospital dropdown
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedHospitalId,
                  dropdownColor: AppColors.cardElevated,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Hospital',
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.driverBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.local_hospital_rounded, color: AppColors.driverBlue, size: 17),
                    ),
                  ),
                  items: _hospitals
                      .map((h) => DropdownMenuItem(
                            value: h.id,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  h.name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (h.address != null && h.address!.isNotEmpty)
                                  Text(
                                    h.address!,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedHospitalId = v),
                  validator: (v) => v == null ? 'Select a hospital' : null,
                ),
              ),

              const SizedBox(height: 20),

              // Terms checkbox card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _termsAccepted
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                ),
                child: CheckboxListTile(
                  value: _termsAccepted,
                  onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                  activeColor: AppColors.primary,
                  checkColor: AppColors.background,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I certify all information is accurate and I am employed by the selected hospital. I accept the Terms of Service.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Register button with gradient
              Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C6AE), Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _handleRegister,
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'REGISTER AS DRIVER',
                              style: TextStyle(
                                color: Colors.white,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 14),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType keyboard = TextInputType.text,
    bool caps = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 17),
          ),
        ),
        keyboardType: keyboard,
        textCapitalization:
            caps ? TextCapitalization.characters : TextCapitalization.none,
        validator: validator,
      ),
    );
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'This field is required' : null;
}
