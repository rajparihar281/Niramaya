import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:niramaya_shared/realtime_service.dart';
import '../core/theme.dart';

class IntakePanel extends StatelessWidget {
  final DispatchUpdate dispatch;
  final VoidCallback onConfirmPickup;
  final VoidCallback onConfirmDropoff;

  const IntakePanel({
    super.key, 
    required this.dispatch,
    required this.onConfirmPickup,
    required this.onConfirmDropoff,
  });

  @override
  Widget build(BuildContext context) {
    if (!['assigned', 'en_route_pickup', 'arrived_pickup', 'en_route_hospital'].contains(dispatch.status)) {
       return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
           color: AppColors.surfaceDark.withValues(alpha: 0.92),
           padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
           child: SafeArea(
             top: false,
             child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Center(
                     child: Container(
                        width: 32, height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                     )
                   ),
                   const SizedBox(height: 16),
                   
                   if (['assigned', 'en_route_pickup', 'arrived_pickup'].contains(dispatch.status)) ...[
                      // Pickup Phase Layout
                      const Text('PICKUP PHASE', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                           Icon(Icons.person, color: AppColors.emergencyRed),
                           SizedBox(width: 8),
                           Text('Emergency Patient', style: TextStyle(color: AppColors.textOnDark, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                         children: [
                           Expanded(
                             child: OutlinedButton.icon(
                               onPressed: () => launchUrl(Uri.parse('tel:108')),
                               icon: const Icon(Icons.call, color: Colors.white),
                               label: const Text('Call Disp.', style: TextStyle(color: Colors.white)),
                               style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(vertical: 14)),
                             ),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                             flex: 2,
                             child: ElevatedButton(
                               onPressed: onConfirmPickup,
                               style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergencyRed, padding: const EdgeInsets.symmetric(vertical: 14)),
                               child: const Text('Confirm Pickup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             ),
                           )
                         ],
                      )
                   ] else if (dispatch.status == 'en_route_hospital') ...[
                      // Dropoff Phase Layout
                      const Text('DROPOFF PHASE', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                           const Icon(Icons.local_hospital, color: AppColors.hospitalGreen),
                           const SizedBox(width: 8),
                           Expanded(child: Text(dispatch.hospitalName ?? 'Assigned Hospital', style: const TextStyle(color: AppColors.textOnDark, fontSize: 18, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Bed Count Row
                      Row(
                         children: [
                            Expanded(child: _BedCard(title: 'Emergency', count: 6)), // Example count, normally fetched via provider
                            const SizedBox(width: 12),
                            Expanded(child: _BedCard(title: 'ICU Beds', count: 2)), // Example count
                         ],
                      ),
                      
                      const SizedBox(height: 24),
                      Row(
                         children: [
                           Expanded(
                             child: OutlinedButton.icon(
                               onPressed: () => launchUrl(Uri.parse('tel:108')),
                               icon: const Icon(Icons.call, color: AppColors.hospitalGreen),
                               label: const Text('Call', style: TextStyle(color: AppColors.hospitalGreen)),
                               style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.hospitalGreen), padding: const EdgeInsets.symmetric(vertical: 14)),
                             ),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                             flex: 2,
                             child: ElevatedButton(
                               onPressed: onConfirmDropoff,
                               style: ElevatedButton.styleFrom(backgroundColor: AppColors.hospitalGreen, padding: const EdgeInsets.symmetric(vertical: 14)),
                               child: const Text('Confirm Dropoff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             ),
                           )
                         ],
                      )
                   ]
                ],
             )
           ),
        ),
      )
    );
  }
}

class _BedCard extends StatelessWidget {
  final String title;
  final int count;

  const _BedCard({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.emergencyRed.withValues(alpha: 0.2);
    Color fg = AppColors.emergencyRed;
    
    if (count >= 5) {
       bg = AppColors.hospitalGreen.withValues(alpha: 0.2);
       fg = AppColors.hospitalGreen;
    } else if (count > 0) {
       bg = AppColors.warningAmber.withValues(alpha: 0.2);
       fg = AppColors.warningAmber;
    }

    return Container(
       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
       decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fg.withValues(alpha: 0.3))),
       child: Column(
          children: [
             Text(count.toString(), style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()])),
             Text(title, style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
       ),
    );
  }
}
