// ── Dispatch Alert Overlay — Full-screen emergency alert ─────────────────────

import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/sha_utils.dart';
import '../models/dispatch_model.dart';

class DispatchAlertOverlay extends StatefulWidget {
  final DispatchModel dispatch;
  final String hospitalName;
  final double? distanceKm;
  final VoidCallback onAcknowledge;

  const DispatchAlertOverlay({
    super.key,
    required this.dispatch,
    required this.hospitalName,
    this.distanceKm,
    required this.onAcknowledge,
  });

  @override
  State<DispatchAlertOverlay> createState() => _DispatchAlertOverlayState();
}

class _DispatchAlertOverlayState extends State<DispatchAlertOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ring1;
  late AnimationController _ring2;
  late AnimationController _iconPulse;
  late AnimationController _slideController;

  late Animation<double> _r1Anim;
  late Animation<double> _r2Anim;
  late Animation<double> _iconScale;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _ring1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _ring2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _iconPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _r1Anim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _ring1, curve: Curves.easeInOut),
    );
    _r2Anim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ring2, curve: Curves.easeInOut),
    );
    _iconScale = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _iconPulse, curve: Curves.easeInOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _slideController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ring1.dispose();
    _ring2.dispose();
    _iconPulse.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFCC0020),
              Color(0xFF8B0000),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Double-ring pulsing icon
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _r2Anim,
                              builder: (_, __) => Transform.scale(
                                scale: _r2Anim.value,
                                child: Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _r1Anim,
                              builder: (_, __) => Transform.scale(
                                scale: _r1Anim.value,
                                child: Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.06),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ScaleTransition(
                              scale: _iconScale,
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.emergency,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'NEW DISPATCH',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ASSIGNED TO YOU',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // Info card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.person_outline,
                              label: 'Patient',
                              value: ShaUtils.truncateHash(widget.dispatch.patientId),
                            ),
                            const SizedBox(height: 14),
                            _InfoRow(
                              icon: Icons.local_hospital_outlined,
                              label: 'Hospital',
                              value: widget.hospitalName,
                            ),
                            if (widget.distanceKm != null) ...[
                              const SizedBox(height: 14),
                              _InfoRow(
                                icon: Icons.directions_rounded,
                                label: 'Distance',
                                value: '${widget.distanceKm!.toStringAsFixed(1)} km',
                              ),
                            ],
                            const SizedBox(height: 14),
                            _InfoRow(
                              icon: Icons.schedule_rounded,
                              label: 'ETA',
                              value: widget.distanceKm != null
                                  ? '~${(widget.distanceKm! / 40 * 60).ceil()} min'
                                  : '—',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Acknowledge button
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onAcknowledge,
                            borderRadius: BorderRadius.circular(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.check_circle_outline, color: Color(0xFFCC0020), size: 24),
                                SizedBox(width: 10),
                                Text(
                                  'ACKNOWLEDGE',
                                  style: TextStyle(
                                    color: Color(0xFFCC0020),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 18),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
