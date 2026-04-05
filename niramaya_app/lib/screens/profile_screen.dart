import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../data/models/patient_record.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _allergiesCtrl;
  late TextEditingController _conditionsCtrl;
  late TextEditingController _emergNameCtrl;
  late TextEditingController _emergPhoneCtrl;
  String? _selectedGender;
  String? _selectedBloodGroup;

  static const _genders = ['male', 'female', 'other', 'prefer_not_to_say'];
  static const _genderLabels = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
    'prefer_not_to_say': 'Prefer not to say',
  };
  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _ageCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _allergiesCtrl = TextEditingController();
    _conditionsCtrl = TextEditingController();
    _emergNameCtrl = TextEditingController();
    _emergPhoneCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _allergiesCtrl.dispose();
    _conditionsCtrl.dispose();
    _emergNameCtrl.dispose();
    _emergPhoneCtrl.dispose();
    super.dispose();
  }

  void _populateForm(PatientRecord? record) {
    final user = ref.read(authProvider).user;
    _nameCtrl.text = record?.fullName ?? '';
    _ageCtrl.text = record?.age?.toString() ?? '';
    _phoneCtrl.text = user?.phone ?? '';
    _emailCtrl.text = user?.email ?? '';
    _selectedGender = record?.gender;
    _selectedBloodGroup = record?.bloodGroup;
    _allergiesCtrl.text = record?.allergies ?? '';
    _conditionsCtrl.text = record?.existingConditions ?? '';
    _emergNameCtrl.text = record?.emergencyContactName ?? '';
    _emergPhoneCtrl.text = record?.emergencyContactPhone ?? '';
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    final record = PatientRecord(
      userId: userId,
      fullName: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text.trim()),
      gender: _selectedGender,
      bloodGroup: _selectedBloodGroup,
      allergies: _allergiesCtrl.text.trim().isEmpty
          ? null
          : _allergiesCtrl.text.trim(),
      existingConditions: _conditionsCtrl.text.trim().isEmpty
          ? null
          : _conditionsCtrl.text.trim(),
      emergencyContactName: _emergNameCtrl.text.trim().isEmpty
          ? null
          : _emergNameCtrl.text.trim(),
      emergencyContactPhone: _emergPhoneCtrl.text.trim().isEmpty
          ? null
          : _emergPhoneCtrl.text.trim(),
      consentGiven: true,
    );

    final success = await ref.read(patientProvider.notifier).saveRecord(record);

    if (!mounted) return;

    if (success) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final error = ref.read(patientProvider).error ?? 'Save failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.emergency),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientState = ref.watch(patientProvider);
    final record = patientState.record;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () {
                _populateForm(record);
                setState(() => _isEditing = true);
              },
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: patientState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isEditing
          ? _buildEditForm()
          : _buildReadView(record),
    );
  }

  Widget _buildReadView(PatientRecord? record) {
    if (record == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No profile yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your health profile for emergencies',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _populateForm(null);
                setState(() => _isEditing = true);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Profile'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar + Name header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      (record.fullName ?? 'U')
                          .split(' ')
                          .take(2)
                          .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
                          .join(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.fullName ?? 'Not set',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: record.consentGiven
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.emergency.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            record.consentGiven
                                ? '✓ Consent Given'
                                : '✗ No Consent',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: record.consentGiven
                                  ? AppColors.success
                                  : AppColors.emergency,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow('Age', record.age?.toString() ?? 'Not set'),
                  _infoRow(
                    'Phone',
                    ref.watch(authProvider).user?.phone ?? 'Not set',
                  ),
                  _infoRow(
                    'Email',
                    ref.watch(authProvider).user?.email ?? 'Not set',
                  ),
                  _infoRow('Gender', _genderLabels[record.gender] ?? 'Not set'),
                  _infoRow('Blood Group', record.bloodGroup ?? 'Not set'),
                  _infoRow('Allergies', record.allergies ?? 'None'),
                  _infoRow(
                    'Existing Conditions',
                    record.existingConditions ?? 'None',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Emergency contact card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.emergency,
                        color: AppColors.emergency,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Emergency Contact',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow('Name', record.emergencyContactName ?? 'Not set'),
                  _infoRow('Phone', record.emergencyContactPhone ?? 'Not set'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Edit button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _populateForm(record);
                setState(() => _isEditing = true);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
          ),
          const SizedBox(height: 80), // Fab space
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Profile',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'This information helps hospitals respond faster during emergencies',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                fillColor: Colors.grey.withValues(alpha: 0.1),
                filled: true,
                helperText: 'Verified via ABHA',
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _ageCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Age',
                prefixIcon: const Icon(Icons.cake_outlined),
                fillColor: Colors.grey.withValues(alpha: 0.1),
                filled: true,
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _phoneCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_iphone_outlined),
                fillColor: Colors.grey.withValues(alpha: 0.1),
                filled: true,
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _emailCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                fillColor: Colors.grey.withValues(alpha: 0.1),
                filled: true,
              ),
            ),

            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: InputDecoration(
                labelText: 'Gender',
                prefixIcon: const Icon(Icons.wc_outlined),
                fillColor: Colors.grey.withValues(alpha: 0.1),
                filled: true,
              ),
              items: _genders
                  .map(
                    (g) => DropdownMenuItem(
                      value: g,
                      child: Text(_genderLabels[g] ?? g),
                    ),
                  )
                  .toList(),
              onChanged: null,
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _selectedBloodGroup,
              decoration: const InputDecoration(
                labelText: 'Blood Group',
                prefixIcon: Icon(Icons.bloodtype_outlined),
              ),
              items: _bloodGroups
                  .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedBloodGroup = v),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _allergiesCtrl,
              decoration: const InputDecoration(
                labelText: 'Allergies',
                prefixIcon: Icon(Icons.warning_amber_outlined),
                hintText: 'e.g., Penicillin, Peanuts',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _conditionsCtrl,
              decoration: const InputDecoration(
                labelText: 'Existing Conditions',
                prefixIcon: Icon(Icons.medical_information_outlined),
                hintText: 'e.g., Diabetes, Hypertension',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            const Text(
              'Emergency Contact',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _emergNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _emergPhoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isEditing = false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    child: ref.watch(patientProvider).isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Profile'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
