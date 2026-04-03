import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/dispatch_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/sos_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatientData();
    });
  }

  Future<void> _loadPatientData() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      await ref.read(patientProvider.notifier).fetchRecord(userId);
    }
  }

  Future<void> _handleSosTrigger() async {
    // 1. Get location
    setState(() {});

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required for SOS')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location permission in settings')),
        );
        return;
      }

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Requesting emergency help...'),
                ],
              ),
            ),
          ),
        ),
      );

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final abhaId = ref.read(authProvider).user?.abhaId ?? '';

      final success = await ref.read(dispatchProvider.notifier).triggerDispatch(
            patientId: abhaId,
            latitude: position.latitude,
            longitude: position.longitude,
          );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      if (success) {
        final dispatch = ref.read(dispatchProvider).dispatch;
        Navigator.pushNamed(context, '/dispatch', arguments: {
          'dispatch': dispatch,
          'userLat': position.latitude,
          'userLng': position.longitude,
        });
      } else {
        final error = ref.read(dispatchProvider).error ?? 'Dispatch failed';
        _showErrorDialog(error);
      }
    } catch (e) {
      if (!mounted) return;
      // Dismiss loading if shown
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.emergency),
            SizedBox(width: 8),
            Text('Dispatch Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSosTrigger();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider);
    final patientState = ref.watch(patientProvider);
    final name = patientState.record?.fullName;
    final consentGiven = patientState.record?.consentGiven ?? false;
    final greeting = name != null && name.isNotEmpty ? 'Hello, $name' : 'Hello';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Niramaya'),
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadPatientData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        child: const Icon(Icons.person, color: AppColors.accent, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Welcome to Niramaya Emergency Services',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
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

              // Consent Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        consentGiven
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        color: consentGiven ? AppColors.success : AppColors.warning,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Health Data Consent',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              consentGiven
                                  ? 'Your data is shared with hospitals during emergencies'
                                  : 'Set up your consent in settings',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: consentGiven
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          consentGiven ? 'Active' : 'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: consentGiven ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Profile completion prompt
              if (name == null || name.isEmpty)
                Card(
                  color: AppColors.accent.withValues(alpha: 0.05),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note, color: AppColors.accent, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Complete your health profile for faster emergency response',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.accent),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // SOS Button
              SosButton(onTriggered: _handleSosTrigger),

              const SizedBox(height: 32),

              // How it works section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'How it works',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _HowItWorksCard(
                    icon: Icons.touch_app,
                    title: 'Press SOS',
                    subtitle: 'Long-press the emergency button',
                    color: AppColors.emergency,
                  )),
                  Expanded(child: _HowItWorksCard(
                    icon: Icons.send_rounded,
                    title: 'Alert Sent',
                    subtitle: 'Nearest hospital is notified',
                    color: AppColors.accent,
                  )),
                  Expanded(child: _HowItWorksCard(
                    icon: Icons.local_hospital,
                    title: 'Help Arrives',
                    subtitle: 'Ambulance dispatched to you',
                    color: AppColors.success,
                  )),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _HowItWorksCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
