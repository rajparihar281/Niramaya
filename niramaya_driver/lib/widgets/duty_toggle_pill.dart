// ── Duty Toggle Pill — Premium animated ON/OFF switch ───────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

class DutyTogglePill extends StatelessWidget {
  final bool isOnDuty;
  final VoidCallback onTap;
  final bool isLoading;

  const DutyTogglePill({
    super.key,
    required this.isOnDuty,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        width: 228,
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: isOnDuty
              ? const LinearGradient(
                  colors: [Color(0xFF00C6AE), Color(0xFF0EA5E9)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isOnDuty ? null : AppColors.dutyOff,
          border: Border.all(
            color: isOnDuty ? Colors.transparent : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isOnDuty
              ? [
                  BoxShadow(
                    color: AppColors.dutyOn.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            // Sliding circle indicator
            AnimatedPositioned(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOut,
              left: isOnDuty ? 228 - 62.0 : 4,
              top: 4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: (isOnDuty ? AppColors.dutyOn : AppColors.textMuted)
                          .withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: isOnDuty ? AppColors.dutyOn : AppColors.textMuted,
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            isOnDuty ? Icons.power_settings_new : Icons.power_off,
                            key: ValueKey(isOnDuty),
                            color: isOnDuty ? AppColors.dutyOn : AppColors.textMuted,
                            size: 26,
                          ),
                        ),
                ),
              ),
            ),

            // Label text
            Center(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 380),
                padding: EdgeInsets.only(
                  left: isOnDuty ? 0 : 48,
                  right: isOnDuty ? 48 : 0,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                    key: ValueKey(isOnDuty),
                    style: TextStyle(
                      color: isOnDuty ? Colors.white : AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
