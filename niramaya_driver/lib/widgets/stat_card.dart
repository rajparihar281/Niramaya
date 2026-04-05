// ── Stat Card — Daily stats display widget ───────────────────────────────────

import 'package:flutter/material.dart';
import '../core/theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final Color? iconColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final ic = iconColor ?? AppColors.primary;
    final vc = valueColor ?? AppColors.textPrimary;
    final isDash = value == '—';

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient icon bg
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ic.withValues(alpha: 0.25),
                    ic.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ic.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: ic, size: 20),
            ),
            const SizedBox(height: 10),
            // Value — shimmer placeholder for empty
            isDash
                ? Container(
                    width: 32,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.cardElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      color: vc,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
