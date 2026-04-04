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

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  String? _editedBloodGroup;
  bool _isDirty = false;
  bool _isSaving = false;

  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  final List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(authProvider).profile;
      if (profile != null) {
        setState(() => _editedBloodGroup = profile.bloodGroup);
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final success = await ref
        .read(driverProfileProvider.notifier)
        .updateEditableFields(bloodGroup: _editedBloodGroup);

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) _isDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(success ? 'Profile updated successfully' : 'Failed to save'),
            ],
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile      = ref.watch(authProvider).profile;
    final hospitalName = ref.watch(hospitalNameProvider(profile?.hospitalId ?? ''));

    if (profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final hospName = hospitalName.when(
      data: (n) => n,
      loading: () => '...',
      error: (_, _) => 'Unknown',
    );

    final initials = (profile.fullName?.isNotEmpty == true)
        ? profile.fullName!
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : 'D';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('PROFILE'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('LOGOUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: () async {
                final nav = Navigator.of(context);
                await ref.read(authProvider.notifier).logout();
                nav.pushNamedAndRemoveUntil('/login', (r) => false);
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Avatar with animated glow ring
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C6AE), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: _glowAnim.value * 0.5),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            Text(
              profile.fullName ?? '—',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),

            // Hospital + rating row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      hospName,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 15),
                    const SizedBox(width: 3),
                    Text(
                      profile.rating.toStringAsFixed(2),
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Verified badge
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: profile.isVerified
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: profile.isVerified
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    profile.isVerified ? Icons.verified_rounded : Icons.pending_rounded,
                    size: 14,
                    color: profile.isVerified ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    profile.isVerified ? 'Verified Driver' : 'Pending Verification',
                    style: TextStyle(
                      color: profile.isVerified ? AppColors.success : AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Identity section
            _SectionCard(
              label: 'IDENTITY',
              icon: Icons.badge_outlined,
              children: [
                _ReadonlyRow('Staff ID', profile.staffId, Icons.badge_rounded, AppColors.primary),
                _ReadonlyRow('Phone', profile.phone ?? '—', Icons.phone_rounded, AppColors.success),
                _ReadonlyRow('Email', profile.email ?? '—', Icons.email_rounded, AppColors.primary),
              ],
            ),

            const SizedBox(height: 12),

            // Professional section
            _SectionCard(
              label: 'PROFESSIONAL',
              icon: Icons.verified_user_outlined,
              children: [
                _ReadonlyRow('License', profile.licenseNumber ?? '—', Icons.credit_card_rounded, AppColors.warning),
                _ReadonlyRow('Experience', '${profile.yearsExperience} years', Icons.timer_rounded, AppColors.primary),
              ],
            ),

            const SizedBox(height: 12),

            // Editable section
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Text(
                        'EDITABLE',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _editedBloodGroup,
                    dropdownColor: AppColors.cardElevated,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    decoration: const InputDecoration(
                      labelText: 'Blood Group',
                      prefixIcon: Icon(Icons.bloodtype_rounded, color: AppColors.textMuted),
                    ),
                    items: _bloodGroups
                        .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _editedBloodGroup = v);
                      _markDirty();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            if (_isDirty)
              Container(
                width: double.infinity,
                height: 54,
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
                    onTap: _isSaving ? null : _save,
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'SAVE CHANGES',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
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
}

class _SectionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.label,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ReadonlyRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ReadonlyRow(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
