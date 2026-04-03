import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/models/dispatch_model.dart';

class DispatchPanel extends StatelessWidget {
  final DispatchModel dispatch;
  final DispatchStatusModel? status;
  final VoidCallback onCancel;

  const DispatchPanel({
    super.key,
    required this.dispatch,
    this.status,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = status?.status ?? 'assigned';
    final displayStatus = _statusLabel(statusText);
    final statusColor = _statusColor(statusText);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayStatus,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Hospital name
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.emergency.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_hospital,
                        color: AppColors.emergency,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dispatch.hospital,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Nearest available hospital',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ETA + Distance
                Row(
                  children: [
                    Expanded(
                      child: _infoTile(
                        Icons.timer_outlined,
                        '${dispatch.etaMinutes.toInt()} min',
                        'Estimated ETA',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.divider,
                    ),
                    Expanded(
                      child: _infoTile(
                        Icons.straighten,
                        dispatch.distance,
                        'Distance',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Guardian alerts
                if (dispatch.guardianAlertsEmitted > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.family_restroom,
                            color: AppColors.accent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${dispatch.guardianAlertsEmitted} family member(s) notified',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("I'm Safe / Cancel"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.success),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'Ambulance dispatched — on the way';
      case 'en_route':
        return 'Ambulance en route';
      case 'arrived':
        return 'Ambulance has arrived';
      case 'completed':
        return 'Dispatch completed';
      default:
        return 'Status: $status';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return AppColors.accent;
      case 'en_route':
        return AppColors.warning;
      case 'arrived':
        return AppColors.success;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}
