// ── Profile Screen — Driver profile with editable fields ────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/driver_profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _editedBloodGroup;
  bool _isDirty = false;
  bool _isSaving = false;

  final List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(authProvider).profile;
      if (profile != null) {
        _editedBloodGroup = profile.bloodGroup;
      }
    });
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final success =
        await ref.read(driverProfileProvider.notifier).updateEditableFields(
              bloodGroup: _editedBloodGroup,
            );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) _isDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profile updated' : 'Failed to save'),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final hospitalName = ref.watch(
      hospitalNameProvider(profile?.hospitalId ?? ''),
    );

    if (profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final hospName = hospitalName.when(
      data: (n) => n,
      loading: () => '...',
      error: (_, _) => 'Unknown',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('PROFILE'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.danger),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (!mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (r) => false);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  (profile.fullName?.isNotEmpty == true)
                      ? profile.fullName![0].toUpperCase()
                      : 'D',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              profile.fullName ?? '—',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  hospName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('·',
                    style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(width: 8),
                Icon(Icons.star, color: AppColors.warning, size: 16),
                const SizedBox(width: 3),
                Text(
                  profile.rating.toStringAsFixed(2),
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Identity section
            _sectionHeader('IDENTITY', Icons.badge),
            _readOnlyField('Staff ID', profile.staffId),
            _readOnlyField('Phone', profile.phone ?? '—'),
            _readOnlyField('Email', profile.email ?? '—'),

            const SizedBox(height: 20),

            // Professional section
            _sectionHeader('PROFESSIONAL', Icons.verified_user),
            _readOnlyField('License No', profile.licenseNumber ?? '—'),
            _readOnlyField('Experience', '${profile.yearsExperience} years'),
            _readOnlyField(
              'Verified',
              profile.isVerified ? '✅ VERIFIED' : '⏳ PENDING',
            ),

            const SizedBox(height: 20),

            // Editable section
            _sectionHeader('EDITABLE', Icons.edit),
            const SizedBox(height: 12),

            // Blood Group dropdown
            DropdownButtonFormField<String>(
              initialValue: _editedBloodGroup,
              dropdownColor: AppColors.card,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 16),
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
              onChanged: (v) {
                setState(() => _editedBloodGroup = v);
                _markDirty();
              },
            ),
            const SizedBox(height: 28),

            // Save button (only when dirty)
            if (_isDirty)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SAVE CHANGES',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: AppColors.border),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
