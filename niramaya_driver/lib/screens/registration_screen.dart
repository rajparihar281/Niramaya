// ── Registration Screen — Single insert into public.drivers ─────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/hospital_model.dart';
import '../services/supabase_service.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _staffIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();

  String? _selectedBloodGroup;
  String? _selectedHospitalId;
  bool _termsAccepted = false;
  bool _isLoading = false;
  List<HospitalModel> _hospitals = [];

  final List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must accept the Terms of Service'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (_selectedHospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a hospital'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Single atomic insert into unified drivers table
      await SupabaseService.client.from('drivers').insert({
        'staff_id': _staffIdCtrl.text.trim(),
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _staffIdCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _licenseCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('REGISTER AS DRIVER'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('PERSONAL INFORMATION'),
                const SizedBox(height: 12),
                _buildField('Full Name', _nameCtrl, Icons.person,
                    validator: _required),
                _buildField('Staff ID', _staffIdCtrl, Icons.badge,
                    validator: _required,
                    caps: true,
                    hint: 'Choose your staff ID'),
                _buildField('Phone', _phoneCtrl, Icons.phone,
                    validator: _required, keyboard: TextInputType.phone),
                _buildField('Email', _emailCtrl, Icons.email,
                    keyboard: TextInputType.emailAddress),

                const SizedBox(height: 24),
                _sectionLabel('PROFESSIONAL DETAILS'),
                const SizedBox(height: 12),
                _buildField('License Number', _licenseCtrl, Icons.credit_card,
                    validator: _required),
                _buildField(
                    'Years of Experience', _experienceCtrl, Icons.timer,
                    keyboard: TextInputType.number),

                DropdownButtonFormField<String>(
                  initialValue: _selectedBloodGroup,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Blood Group',
                    prefixIcon:
                        Icon(Icons.bloodtype, color: AppColors.textMuted),
                  ),
                  items: _bloodGroups
                      .map((bg) => DropdownMenuItem(
                            value: bg,
                            child: Text(bg),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBloodGroup = v),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedHospitalId,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Hospital',
                    prefixIcon: Icon(Icons.local_hospital,
                        color: AppColors.textMuted),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (h.address != null && h.address!.isNotEmpty)
                                  Text(
                                    h.address!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
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
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _termsAccepted,
                        onChanged: (v) =>
                            setState(() => _termsAccepted = v ?? false),
                        activeColor: AppColors.primary,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'I certify all information is accurate and I am employed by the selected hospital. I accept the Terms of Service.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
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
                            'REGISTER',
                            style: TextStyle(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
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

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
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
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textMuted),
        ),
        keyboardType: keyboard,
        textCapitalization:
            caps ? TextCapitalization.characters : TextCapitalization.none,
        validator: validator,
      ),
    );
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;
}
