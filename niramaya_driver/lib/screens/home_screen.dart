// ── Home Screen — Primary driver dashboard ──────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/dispatch_provider.dart';
import '../providers/duty_provider.dart';
import '../providers/driver_profile_provider.dart';
import '../services/location_service.dart';
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
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late Animation<double> _radarAnimation;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);
    _radarAnimation = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDriverState();
    });
  }

  void _initDriverState() {
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;
    ref.read(dutyProvider.notifier).setDuty(profile.isOnDuty);
    ref.read(driverProfileProvider.notifier).setProfile(profile);
    ref.read(dispatchProvider.notifier).initRealtimeSubscription(profile.id);
    if (profile.isOnDuty) {
      LocationService.instance.startLocationBroadcast(profile.id);
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState    = ref.watch(authProvider);
    final profile      = authState.profile;
    final isOnDuty     = ref.watch(dutyProvider).isOnDuty;
    final isDutyToggling = ref.watch(dutyProvider).isToggling;
    final dispatchState  = ref.watch(dispatchProvider);
    final hospitalName   = ref.watch(hospitalNameProvider(profile?.hospitalId ?? ''));

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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        backgroundColor: Colors.transparent,
        elevation: 0,
        onTap: (i) {
          if (i == 1) {
            Navigator.of(context).pushNamed('/history');
          } else if (i == 2) {
            Navigator.of(context).pushNamed('/profile');
          } else {
            setState(() => _currentNavIndex = i);
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: _currentNavIndex == 0
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.home_rounded),
            ),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
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
        _buildTopBar(profile, hospitalName),
        const SizedBox(height: 20),

        // Duty toggle
        Center(
          child: DutyTogglePill(
            isOnDuty: isOnDuty,
            isLoading: isDutyToggling,
            onTap: () => _toggleDuty(profile),
          ),
        ),

        const SizedBox(height: 20),

        // Content
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2E), AppColors.card],
        ),
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Avatar with gradient ring
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00C6AE), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                (profile?.fullName ?? 'D').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + ID
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
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Hospital chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_hospital_outlined, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  hospName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Rating
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.warning, size: 14),
                const SizedBox(width: 3),
                Text(
                  (profile?.rating ?? 5.0).toStringAsFixed(1),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Status card
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOnDuty
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
            gradient: isOnDuty
                ? LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnDuty ? AppColors.primary : AppColors.textMuted,
                      boxShadow: isOnDuty
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DUTY STATUS',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                style: TextStyle(
                  color: isOnDuty ? AppColors.primary : AppColors.textMuted,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isOnDuty
                    ? 'You are visible to dispatch'
                    : 'Toggle above to go on duty',
                style: TextStyle(
                  color: isOnDuty ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (isOnDuty) ...[
                const SizedBox(height: 24),
                ScaleTransition(
                  scale: _radarAnimation,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.07),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.radar, color: AppColors.primary, size: 34),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
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

        const SizedBox(height: 14),

        // Driver info card
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('DRIVER INFO', Icons.person_outline),
              const SizedBox(height: 16),
              _infoRow(Icons.person_rounded, 'Name',
                  profile?.fullName ?? '—', AppColors.primary),
              _divider(),
              _infoRow(Icons.bloodtype_rounded, 'Blood Group',
                  profile?.bloodGroup ?? '—', AppColors.emergency),
              _divider(),
              _infoRow(Icons.credit_card_rounded, 'License',
                  profile?.licenseNumber ?? '—', AppColors.warning),
              _divider(),
              _infoRow(Icons.timer_rounded, 'Experience',
                  '${profile?.yearsExperience ?? 0} yrs', AppColors.success),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Hospital card
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('ASSIGNED HOSPITAL', Icons.local_hospital_outlined),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.driverBlue.withValues(alpha: 0.2),
                          AppColors.driverBlue.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.driverBlue.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: AppColors.driverBlue,
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

        const SizedBox(height: 14),

        // Stats row
        Row(
          children: [
            StatCard(
              label: 'Trips Today',
              value: '—',
              icon: Icons.local_shipping_rounded,
              iconColor: AppColors.primary,
            ),
            const SizedBox(width: 10),
            StatCard(
              label: 'Total KM',
              value: '—',
              icon: Icons.route_rounded,
              iconColor: AppColors.warning,
            ),
            const SizedBox(width: 10),
            StatCard(
              label: 'Hours On',
              value: '—',
              icon: Icons.timer_rounded,
              iconColor: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
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
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(vertical: 10),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveDispatch(DispatchState dispatchState, dynamic profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        children: [
          DispatchCard(
            dispatch: dispatchState.activeDispatch!,
            hospitalName: dispatchState.hospitalName ?? 'Unknown Hospital',
            onOpenMap: () => Navigator.of(context).pushNamed('/map'),
            onConfirmPickup: () =>
                ref.read(dispatchProvider.notifier).confirmPickup(),
            onArrivedHospital: () =>
                ref.read(dispatchProvider.notifier).arrivedAtHospital(),
            onComplete: () {
              if (profile != null) {
                ref.read(dispatchProvider.notifier).completeDispatch(profile.id);
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
    if (profile == null) return;
    final id = profile.id?.toString() ?? '';
    if (id.isEmpty) return;

    final newState = await ref.read(dutyProvider.notifier).toggle(id);

    if (newState) {
      LocationService.instance.startLocationBroadcast(id);
    } else {
      LocationService.instance.stopLocationBroadcast();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState
                ? 'ON DUTY — You are now visible to dispatch'
                : 'OFF DUTY — You will not receive dispatches',
          ),
          backgroundColor: newState ? AppColors.primary : AppColors.cardElevated,
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
