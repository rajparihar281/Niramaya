// ── Home Screen — Primary driver dashboard ──────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/dispatch_provider.dart';
import '../providers/duty_provider.dart';
import '../providers/driver_profile_provider.dart';
import '../widgets/duty_toggle_pill.dart';
import '../widgets/stat_card.dart';
import '../widgets/dispatch_card.dart';
import '../widgets/dispatch_alert_overlay.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  late Animation<double> _radarAnimation;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);

    _radarAnimation = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeInOut),
    );

    // Initialize after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDriverState();
    });
  }

  void _initDriverState() {
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;

    // Sync duty state
    ref.read(dutyProvider.notifier).setDuty(profile.isOnDuty);

    // Set profile
    ref.read(driverProfileProvider.notifier).setProfile(profile);

    // Start realtime dispatch subscription
    if (profile.ambulanceId != null && profile.ambulanceId!.isNotEmpty) {
      ref
          .read(dispatchProvider.notifier)
          .initRealtimeSubscription(profile.ambulanceId!);
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;
    final isOnDuty = ref.watch(dutyProvider).isOnDuty;
    final isDutyToggling = ref.watch(dutyProvider).isToggling;
    final dispatchState = ref.watch(dispatchProvider);
    final hospitalName = ref.watch(
      hospitalNameProvider(profile?.hospitalId ?? ''),
    );

    // Show dispatch alert overlay
    if (dispatchState.uiState == DispatchUiState.alerting &&
        dispatchState.activeDispatch != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDispatchAlert(dispatchState);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: IndexedStack(
          index: _currentNavIndex,
          children: [
            _buildHomePage(profile, isOnDuty, isDutyToggling, dispatchState, hospitalName),
            _buildHistoryPlaceholder(),
            _buildProfilePlaceholder(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (i) {
            if (i == 1) {
              Navigator.of(context).pushNamed('/history');
            } else if (i == 2) {
              Navigator.of(context).pushNamed('/profile');
            } else {
              setState(() => _currentNavIndex = i);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage(
    dynamic profile,
    bool isOnDuty,
    bool isDutyToggling,
    DispatchState dispatchState,
    AsyncValue<String> hospitalName,
  ) {
    return Column(
      children: [
        // Top bar
        _buildTopBar(profile, hospitalName),

        const SizedBox(height: 20),

        // Duty Toggle
        Center(
          child: DutyTogglePill(
            isOnDuty: isOnDuty,
            isLoading: isDutyToggling,
            onTap: () => _toggleDuty(profile),
          ),
        ),

        const SizedBox(height: 24),

        // Content area
        Expanded(
          child: dispatchState.uiState == DispatchUiState.active &&
                  dispatchState.activeDispatch != null
              ? _buildActiveDispatch(dispatchState, profile)
              : _buildIdleState(isOnDuty, profile),
        ),
      ],
    );
  }

  Widget _buildTopBar(dynamic profile, AsyncValue<String> hospitalName) {
    final hospName = hospitalName.when(
      data: (n) => n,
      loading: () => '...',
      error: (_, _) => 'Unknown',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Center(
              child: Text(
                (profile?.fullName ?? 'D').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + staffId
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.fullName ?? 'Driver',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile?.staffId ?? '',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Hospital chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              hospName,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Rating
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: AppColors.warning, size: 14),
                const SizedBox(width: 3),
                Text(
                  (profile?.rating ?? 5.0).toStringAsFixed(2),
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleState(bool isOnDuty, dynamic profile) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Card A — Status
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnDuty
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DUTY STATUS',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                  style: TextStyle(
                    color: isOnDuty
                        ? AppColors.primary
                        : AppColors.textMuted,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOnDuty
                      ? 'You are visible to dispatch'
                      : 'Toggle above to go on duty',
                  style: TextStyle(
                    color: isOnDuty
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (isOnDuty) ...[
                  const SizedBox(height: 20),
                  ScaleTransition(
                    scale: _radarAnimation,
                    child: FadeTransition(
                      opacity: _radarAnimation,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.radar,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scanning for dispatch...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Card B — Driver Info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DRIVER INFO',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                _infoRow(Icons.person, 'Name',
                    profile?.fullName ?? '—'),
                const SizedBox(height: 12),
                _infoRow(Icons.bloodtype, 'Blood Group',
                    profile?.bloodGroup ?? '—'),
                const SizedBox(height: 12),
                _infoRow(Icons.credit_card, 'License',
                    profile?.licenseNumber ?? '—'),
                const SizedBox(height: 12),
                _infoRow(Icons.timer, 'Experience',
                    '${profile?.yearsExperience ?? 0} years'),
              ],
            ),
          ),
        ),

        // Card C — Hospital
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ASSIGNED HOSPITAL',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_hospital,
                        color: AppColors.emergencyBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        profile?.hospitalId != null
                            ? 'Hospital ID: ${profile!.hospitalId}'
                            : 'Not assigned',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Stats row
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Trips Today',
                value: '—',
                icon: Icons.local_shipping,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: StatCard(
                label: 'Total KM',
                value: '—',
                icon: Icons.route,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: StatCard(
                label: 'Hours On',
                value: '—',
                icon: Icons.timer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 16),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
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
    );
  }

  Widget _buildActiveDispatch(DispatchState dispatchState, dynamic profile) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          DispatchCard(
            dispatch: dispatchState.activeDispatch!,
            hospitalName: dispatchState.hospitalName ?? 'Unknown Hospital',
            onOpenMap: () {
              Navigator.of(context).pushNamed('/map');
            },
            onConfirmPickup: () {
              ref.read(dispatchProvider.notifier).confirmPickup();
            },
            onArrivedHospital: () {
              ref.read(dispatchProvider.notifier).arrivedAtHospital();
            },
            onComplete: () {
              if (profile != null) {
                ref
                    .read(dispatchProvider.notifier)
                    .completeDispatch(profile.id);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPlaceholder() {
    return const Center(child: Text('History'));
  }

  Widget _buildProfilePlaceholder() {
    return const Center(child: Text('Profile'));
  }

  Future<void> _toggleDuty(dynamic profile) async {
    if (profile == null) {
      debugPrint('[HomeScreen] _toggleDuty: profile is null — not logged in yet');
      return;
    }
    final id = profile.id?.toString() ?? '';
    if (id.isEmpty) {
      debugPrint('[HomeScreen] _toggleDuty: profile.id is empty — driver row may not be loaded');
      return;
    }
    debugPrint('[HomeScreen] _toggleDuty: using profile.id=$id');

    final newState = await ref.read(dutyProvider.notifier).toggle(id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState
                ? 'ON DUTY — You are now visible to dispatch'
                : 'OFF DUTY — You will not receive dispatches',
          ),
          backgroundColor:
              newState ? AppColors.primary : AppColors.cardElevated,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDispatchAlert(DispatchState dispatchState) {
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (context, anim1, anim2) {
        return DispatchAlertOverlay(
          dispatch: dispatchState.activeDispatch!,
          hospitalName: dispatchState.hospitalName ?? 'Unknown Hospital',
          onAcknowledge: () {
            ref.read(dispatchProvider.notifier).acknowledgeAlert();
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
