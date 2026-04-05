import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

class SosButton extends StatefulWidget {
  final Function(String dispatchId) onDispatchAssigned;
  const SosButton({super.key, required this.onDispatchAssigned});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with TickerProviderStateMixin {
  late AnimationController _pulse1Controller;
  late AnimationController _pulse2Controller;
  late AnimationController _pulse3Controller;
  late AnimationController _holdController;
  late AnimationController _pressController;

  Timer? _holdTimer;
  bool _isHolding = false;

  static const _holdDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();

    _pulse1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulse2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulse3Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _holdController = AnimationController(vsync: this, duration: _holdDuration);

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _pulse1Controller.dispose();
    _pulse2Controller.dispose();
    _pulse3Controller.dispose();
    _holdController.dispose();
    _pressController.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    HapticFeedback.mediumImpact();
    setState(() => _isHolding = true);
    _holdController.forward(from: 0);
    _pressController.forward(from: 0);
    _holdTimer = Timer(_holdDuration, _onHoldComplete);
  }

  void _onTapUp(TapUpDetails _) => _cancelHold();
  void _onTapCancel() => _cancelHold();

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdController.reverse();
    _pressController.reverse();
    if (mounted) setState(() => _isHolding = false);
  }

  void _onHoldComplete() {
    HapticFeedback.heavyImpact();
    if (mounted) setState(() => _isHolding = false);
    _holdController.reset();
    _pressController.reverse();
    Navigator.pushNamed(context, '/sos-trigger');
  }

  Widget _pulseRing(
    AnimationController controller,
    double size,
    double alphaMax,
  ) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final scale = 1.0 + controller.value * 0.22;
        final opacity = 1.0 - controller.value * 0.75;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.emergencyRed.withValues(
                alpha: opacity * alphaMax,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ring 3 — slowest, most transparent
                  _pulseRing(_pulse3Controller, 212, 0.08),
                  // Ring 2 — medium
                  _pulseRing(_pulse2Controller, 175, 0.14),
                  // Ring 1 — fastest, most vibrant
                  _pulseRing(_pulse1Controller, 142, 0.20),

                  // Progress arc during hold
                  AnimatedBuilder(
                    animation: _holdController,
                    builder: (ctx, child) => CustomPaint(
                      size: const Size(168, 168),
                      painter: _ArcPainter(_holdController.value),
                    ),
                  ),

                  // Main button with press compression
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _holdController,
                      _pressController,
                    ]),
                    builder: (ctx, child) {
                      final pressScale = 1.0 - _pressController.value * 0.04;
                      final holdScale = 1.0 - _holdController.value * 0.06;
                      return Transform.scale(
                        scale: pressScale * holdScale,
                        child: Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0xFFFF5263), Color(0xFFBB0020)],
                              center: Alignment(-0.3, -0.3),
                              radius: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.emergencyRed.withValues(
                                  alpha: 0.55,
                                ),
                                blurRadius: 28,
                                spreadRadius: _isHolding ? 8 : 3,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: AppColors.emergencyRed.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 50,
                                spreadRadius: 12,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.emergency,
                                color: Colors.white,
                                size: 42,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isHolding
                ? Row(
                    key: const ValueKey('holding'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.emergencyRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Release to cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emergencyRed,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  )
                : Text(
                    key: const ValueKey('idle'),
                    'Hold to activate',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  _ArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    // Background track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 3,
    );
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, trackPaint);

    // Progress arc
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}
