// ── Dispatch Card — Active dispatch card with status + actions ───────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/sha_utils.dart';
import '../models/dispatch_model.dart';

class DispatchCard extends StatefulWidget {
  final DispatchModel dispatch;
  final String hospitalName;
  final VoidCallback onOpenMap;
  final VoidCallback onConfirmPickup;
  final VoidCallback onArrivedHospital;
  final VoidCallback onComplete;

  const DispatchCard({
    super.key,
    required this.dispatch,
    required this.hospitalName,
    required this.onOpenMap,
    required this.onConfirmPickup,
    required this.onArrivedHospital,
    required this.onComplete,
  });

  @override
  State<DispatchCard> createState() => _DispatchCardState();
}

class _DispatchCardState extends State<DispatchCard>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  String _elapsed = '00:00:00';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _updateElapsed() {
    final d = DateTime.now().difference(widget.dispatch.createdAt);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (mounted) setState(() => _elapsed = '$h:$m:$s');
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.danger.withValues(alpha: 0.18),
                  AppColors.danger.withValues(alpha: 0.06),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.danger
                          .withValues(alpha: _pulseAnim.value),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger
                              .withValues(alpha: _pulseAnim.value * 0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'ACTIVE DISPATCH',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    widget.dispatch.statusDisplay,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info rows
                _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Patient',
                  value: ShaUtils.truncateHash(widget.dispatch.patientId),
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.local_hospital_outlined,
                  label: 'Hospital',
                  value: widget.hospitalName,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.timer_outlined,
                  label: 'Elapsed',
                  value: _elapsed,
                  valueColor: AppColors.warning,
                  monospace: true,
                ),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    // Map button
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onOpenMap,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.cardElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text(
                                'MAP',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action button with gradient
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_actionColor, _actionColor.withValues(alpha: 0.7)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _actionColor.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _actionCallback,
                            borderRadius: BorderRadius.circular(12),
                            child: Center(
                              child: Text(
                                _actionLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _statusColor {
    switch (widget.dispatch.status) {
      case DispatchStatus.assigned:  return AppColors.warning;
      case DispatchStatus.pickedUp:  return AppColors.primary;
      case DispatchStatus.arrived:   return AppColors.success;
      case DispatchStatus.completed: return AppColors.success;
      case DispatchStatus.unknown:   return AppColors.textMuted;
    }
  }

  String get _actionLabel {
    switch (widget.dispatch.status) {
      case DispatchStatus.assigned:  return 'CONFIRM REACH';
      case DispatchStatus.pickedUp:  return 'CONFIRM PICKUP';
      case DispatchStatus.arrived:   return 'COMPLETE';
      default:                       return 'COMPLETE';
    }
  }

  Color get _actionColor {
    switch (widget.dispatch.status) {
      case DispatchStatus.assigned:  return AppColors.warning;
      case DispatchStatus.pickedUp:  return AppColors.primary;
      default:                       return AppColors.success;
    }
  }

  VoidCallback get _actionCallback {
    switch (widget.dispatch.status) {
      case DispatchStatus.assigned:  return widget.onConfirmPickup;
      case DispatchStatus.pickedUp:  return widget.onArrivedHospital;
      default:                       return widget.onComplete;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.cardElevated,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.textMuted, size: 16),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: monospace ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}
