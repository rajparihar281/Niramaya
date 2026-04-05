import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/dispatch_provider.dart';

// Clinical triage categories
enum _TriageCategory { accident, cardiac, maternity }

extension _TriageCategoryX on _TriageCategory {
  String get label {
    switch (this) {
      case _TriageCategory.accident:  return 'ACCIDENT';
      case _TriageCategory.cardiac:   return 'CARDIAC';
      case _TriageCategory.maternity: return 'MATERNITY';
    }
  }

  String get dept {
    switch (this) {
      case _TriageCategory.accident:  return 'trauma';
      case _TriageCategory.cardiac:   return 'cardiology';
      case _TriageCategory.maternity: return 'maternity';
    }
  }

  IconData get icon {
    switch (this) {
      case _TriageCategory.accident:  return Icons.car_crash;
      case _TriageCategory.cardiac:   return Icons.favorite;
      case _TriageCategory.maternity: return Icons.pregnant_woman;
    }
  }

  Color get color {
    switch (this) {
      case _TriageCategory.accident:  return const Color(0xFFFF6B35);
      case _TriageCategory.cardiac:   return const Color(0xFFE8303A);
      case _TriageCategory.maternity: return const Color(0xFF9C27B0);
    }
  }
}

class SosTriggerScreen extends ConsumerStatefulWidget {
  const SosTriggerScreen({super.key});

  @override
  ConsumerState<SosTriggerScreen> createState() => _SosTriggerScreenState();
}

class _SosTriggerScreenState extends ConsumerState<SosTriggerScreen> {
  static const _countdownSeconds = 3;

  final FlutterTts _tts = FlutterTts();

  // Phase: 'triage' | 'fuse' | 'dispatching' | 'success' | 'no_drivers' | 'error'
  String _phase = 'triage';
  int _countdown = _countdownSeconds;
  String? _errorMsg;
  String _requiredDept = 'emergency';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTriage());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTriage() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.speak('Select emergency type.');
  }

  void _selectTriage(_TriageCategory cat) {
    HapticFeedback.mediumImpact();
    _requiredDept = cat.dept;
    setState(() => _phase = 'fuse');
    _startFuse();
  }

  // ── Safety Fuse ──────────────────────────────────────────────────────────

  Future<void> _startFuse() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 500, 200, 500], intensities: [255, 255]);
    }
    await _tts.speak('Dispatching help in 3 seconds. Tap to cancel.');

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _executeDispatch();
      }
    });
  }

  void _cancelSos() {
    _timer?.cancel();
    _tts.stop();
    Vibration.cancel();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
  }

  // ── Atomic Dispatch ──────────────────────────────────────────────────────

  Future<void> _executeDispatch() async {
    setState(() => _phase = 'dispatching');

    try {
      final abhaId = ref.read(authProvider).user?.abhaId;
      if (abhaId == null || abhaId.isEmpty) {
        throw Exception('Identity not found. Please login to Niramaya.');
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied. Cannot dispatch SOS.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final success = await ref.read(dispatchProvider.notifier).triggerDispatch(
            patientId: abhaId,
            latitude: position.latitude,
            longitude: position.longitude,
            requiredDept: _requiredDept,
          );

      if (!mounted) return;
      final dispatchState = ref.read(dispatchProvider);

      if (dispatchState.noDriversAvailable) {
        setState(() => _phase = 'no_drivers');
        return;
      }

      if (!success) throw Exception(dispatchState.error ?? 'Unknown dispatch error.');

      if (await Vibration.hasVibrator()) Vibration.vibrate(duration: 600);
      await _tts.speak('Dispatch successful. Ambulance is on the way.');
      setState(() => _phase = 'success');

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final dispatch = ref.read(dispatchProvider).dispatch;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dispatch',
        (route) => route.settings.name == '/home',
        arguments: {
          'dispatch': dispatch,
          'userLat': position.latitude,
          'userLng': position.longitude,
        },
      );
    } catch (e) {
      if (!mounted) return;

      final isNetworkError = e is SocketException ||
          e is DioException && (
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError
          );

      HapticFeedback.heavyImpact();

      if (isNetworkError) {
        await _tts.speak('Connection failed. Check your network and retry.');
        if (!mounted) return;
        setState(() {
          _phase = 'fuse';
          _countdown = _countdownSeconds;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Connection Error: Please check if the Niramaya Engine is online.'),
          backgroundColor: Colors.deepOrange,
          duration: Duration(seconds: 4),
        ));
      } else {
        await _tts.speak('SOS failed. Please retry or call emergency services.');
        setState(() {
          _phase = 'error';
          _errorMsg = e.toString();
        });
      }
    }
  }

  void _broadcastPrivate() {
    _tts.speak('Broadcasting to private ambulances. Please stay calm.');
    _executeDispatch();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scanningHospital = ref.watch(dispatchProvider).scanningHospital;

    return Scaffold(
      backgroundColor: AppColors.emergency,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: switch (_phase) {
              'triage' => _TriageView(onSelect: _selectTriage, onCancel: _cancelSos),
              'fuse' => _FuseView(countdown: _countdown, onCancel: _cancelSos),
              'dispatching' => _DispatchingView(hospitalName: scanningHospital ?? 'Scanning grid...'),
              'success' => const _StatusView(
                  icon: Icons.check_circle_outline,
                  label: 'AMBULANCE CONNECTED',
                  sub: 'Help is on the way.',
                ),
              'no_drivers' => _NoDriverView(onBroadcast: _broadcastPrivate, onClose: _cancelSos),
              _ => _ErrorView(
                  message: _errorMsg ?? 'Unknown error.',
                  onRetry: _executeDispatch,
                  onClose: _cancelSos,
                ),
            },
          ),
        ),
      ),
    );
  }
}

// ── Triage View ──────────────────────────────────────────────────────────────

class _TriageView extends StatelessWidget {
  final void Function(_TriageCategory) onSelect;
  final VoidCallback onCancel;
  const _TriageView({required this.onSelect, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.emergency, size: 56, color: Colors.white),
        const SizedBox(height: 16),
        const Text(
          'SELECT EMERGENCY TYPE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This helps route you to the right department',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        ..._TriageCategory.values.map((cat) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SizedBox(
            width: double.infinity,
            height: 72,
            child: ElevatedButton.icon(
              onPressed: () => onSelect(cat),
              icon: Icon(cat.icon, size: 28),
              label: Text(
                cat.label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: cat.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
            ),
          ),
        )),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 15)),
        ),
      ],
    );
  }
}

// ── Fuse View ────────────────────────────────────────────────────────────────

class _FuseView extends StatelessWidget {
  final int countdown;
  final VoidCallback onCancel;
  const _FuseView({required this.countdown, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.emergency, size: 96, color: Colors.white),
        const SizedBox(height: 24),
        Text(
          '$countdown',
          style: const TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'DISPATCHING AMBULANCE',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 72,
          child: ElevatedButton(
            onPressed: onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.emergency,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('CANCEL SOS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

// ── Dispatching View ─────────────────────────────────────────────────────────

class _DispatchingView extends StatelessWidget {
  final String hospitalName;
  const _DispatchingView({required this.hospitalName});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 64, height: 64,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 5),
        ),
        const SizedBox(height: 32),
        const Text(
          'SCANNING GRID',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              'Checking availability at\n$hospitalName',
              key: ValueKey(hospitalName),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Contacting nearest verified driver...', style: TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

// ── No Driver View ───────────────────────────────────────────────────────────

class _NoDriverView extends StatelessWidget {
  final VoidCallback onBroadcast;
  final VoidCallback onClose;
  const _NoDriverView({required this.onBroadcast, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.white),
        const SizedBox(height: 24),
        const Text(
          'NO AMBULANCE\nAVAILABLE',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1, height: 1.3),
        ),
        const SizedBox(height: 12),
        const Text(
          'All  drivers are currently busy\nor off duty in your area.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: onBroadcast,
            icon: const Icon(Icons.cell_tower, size: 22),
            label: const Text('AMBULANCES',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.emergency,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: onClose,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ── Status View ──────────────────────────────────────────────────────────────

class _StatusView extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  const _StatusView({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: Colors.white),
        const SizedBox(height: 32),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}

// ── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  const _ErrorView({required this.message, required this.onRetry, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 80, color: Colors.white),
        const SizedBox(height: 24),
        const Text('SOS FAILED', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.emergency),
            child: const Text('RETRY SOS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: onClose, child: const Text('Close', style: TextStyle(color: Colors.white70))),
      ],
    );
  }
}
