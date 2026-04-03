import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/dispatch_provider.dart';

class SosTriggerScreen extends ConsumerStatefulWidget {
  const SosTriggerScreen({super.key});

  @override
  ConsumerState<SosTriggerScreen> createState() => _SosTriggerScreenState();
}

class _SosTriggerScreenState extends ConsumerState<SosTriggerScreen> {
  static const _countdownSeconds = 3;

  final FlutterTts _tts = FlutterTts();

  // Phase: 'fuse' | 'dispatching' | 'success' | 'error'
  String _phase = 'fuse';
  int _countdown = _countdownSeconds;
  String? _errorMsg;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFuse());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  // ── Safety Fuse ──────────────────────────────────────────────────────────

  Future<void> _startFuse() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);

    // Vibration pulse: [delay, on, off, on]
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 500, 200, 500], intensities: [255, 255]);
    }

    await _tts.speak(
      'Emergency SOS detected. Dispatching help in 3 seconds. Tap to cancel.',
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
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
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    }
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
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied. Cannot dispatch SOS.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final success = await ref.read(dispatchProvider.notifier).triggerDispatch(
            patientId: abhaId,
            latitude: position.latitude,
            longitude: position.longitude,
          );

      if (!mounted) return;

      if (!success) {
        throw Exception(
            ref.read(dispatchProvider).error ?? 'Unknown dispatch error.');
      }

      // ── Success ──
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 600);
      }
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
      HapticFeedback.heavyImpact();
      await _tts.speak('SOS failed. Please retry or call emergency services.');
      setState(() {
        _phase = 'error';
        _errorMsg = e.toString();
      });
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.emergency,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: switch (_phase) {
              'fuse' => _FuseView(
                  countdown: _countdown,
                  onCancel: _cancelSos,
                ),
              'dispatching' => _StatusView(
                  icon: Icons.wifi_tethering,
                  label: 'TRANSMITTING SOS...',
                  sub: 'Requesting nearest ambulance.',
                  spinning: true,
                ),
              'success' => _StatusView(
                  icon: Icons.check_circle_outline,
                  label: 'AMBULANCE CONNECTED',
                  sub: 'Help is on the way.',
                ),
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

// ── Sub-widgets ──────────────────────────────────────────────────────────────

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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 96,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'DISPATCHING AMBULANCE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'CANCEL SOS',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusView extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final bool spinning;
  const _StatusView({
    required this.icon,
    required this.label,
    required this.sub,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        spinning
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 4)
            : Icon(icon, size: 80, color: Colors.white),
        const SizedBox(height: 32),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(sub,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  const _ErrorView(
      {required this.message, required this.onRetry, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 80, color: Colors.white),
        const SizedBox(height: 24),
        const Text('SOS FAILED',
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.emergency,
            ),
            child: const Text('RETRY SOS',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onClose,
          child: const Text('Close',
              style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
