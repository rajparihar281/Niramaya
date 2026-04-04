import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/sha_utils.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final List<Map<String, dynamic>> _dispatches = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final profile = ref.read(authProvider).profile;
    if (profile == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final from = _page * AppConstants.historyPageSize;
      final to = from + AppConstants.historyPageSize - 1;

      final result = await SupabaseService.client
          .from('dispatches')
          .select(
            'id, patient_id, hospital_id, status, created_at, '
            'hospital_lat, hospital_lng, patient_lat, patient_lng, '
            'emergency_details, live_eta, live_distance',
          )
          .eq('driver_id', profile.id)
          .order('created_at', ascending: false)
          .range(from, to);

      final rows = await Future.wait(
        List<Map<String, dynamic>>.from(result).map((row) async {
          final hospitalId = row['hospital_id']?.toString();
          if (hospitalId != null) {
            try {
              final h = await SupabaseService.client
                  .from('hospitals')
                  .select('name')
                  .eq('id', hospitalId)
                  .maybeSingle();
              return {...row, 'hospital_name': h?['name'] ?? 'Unknown Hospital'};
            } catch (_) {}
          }
          return {...row, 'hospital_name': 'Unknown Hospital'};
        }),
      );

      setState(() {
        _dispatches.addAll(rows);
        _page++;
        _hasMore = rows.length == AppConstants.historyPageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _dispatches.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dispatch History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: _dispatches.isEmpty && !_isLoading
            ? _buildEmpty()
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _dispatches.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _dispatches.length) return _buildLoader();
                  return _DispatchCard(data: _dispatches[i]);
                },
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: AppColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text(
            'No dispatches yet',
            style: TextStyle(fontSize: 16, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your completed rides will appear here',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      ),
    );
  }
}

// ── Dispatch Card ─────────────────────────────────────────────────────────────
class _DispatchCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _DispatchCard({required this.data});

  @override
  State<_DispatchCard> createState() => _DispatchCardState();
}

class _DispatchCardState extends State<_DispatchCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final status = d['status']?.toString() ?? 'unknown';
    final hospitalName = d['hospital_name']?.toString() ?? 'Unknown Hospital';
    final patientHash = ShaUtils.truncateHash(d['patient_id']?.toString() ?? '');
    final createdAt = DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy · HH:mm').format(createdAt.toLocal());

    final liveEta = d['live_eta']?.toString();
    final liveDist = d['live_distance']?.toString();

    // Emergency details JSONB
    final emergency = d['emergency_details'] as Map<String, dynamic>?;
    final triage = emergency?['triage']?.toString();
    final notes = emergency?['notes']?.toString();

    // Coords
    final hasCoords = d['patient_lat'] != null && d['hospital_lat'] != null;

    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          children: [
            // ── Header row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status icon
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_statusIcon(status), color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                hospitalName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(status: status, label: statusLabel, color: statusColor),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              patientHash,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (triage != null) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.emergencyRed.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  triage.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emergencyRed,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),

            // ── Quick stats row ──────────────────────────────────────────
            if (liveEta != null || liveDist != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: [
                    if (liveDist != null)
                      _StatPill(icon: Icons.straighten, label: liveDist, color: AppColors.driverBlue),
                    if (liveEta != null) ...[
                      const SizedBox(width: 8),
                      _StatPill(icon: Icons.timer_outlined, label: liveEta, color: AppColors.primary),
                    ],
                  ],
                ),
              ),

            // ── Expanded detail section ──────────────────────────────────
            if (_expanded) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dispatch ID
                    _DetailRow(
                      icon: Icons.tag,
                      label: 'Dispatch ID',
                      value: d['id']?.toString().substring(0, 8).toUpperCase() ?? '—',
                      mono: true,
                    ),

                    // Coordinates
                    if (hasCoords) ...[
                      const SizedBox(height: 8),
                      _DetailRow(
                        icon: Icons.my_location,
                        label: 'Patient Location',
                        value: '${(d['patient_lat'] as num).toStringAsFixed(5)}, '
                            '${(d['patient_lng'] as num).toStringAsFixed(5)}',
                        mono: true,
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        icon: Icons.local_hospital,
                        label: 'Hospital Location',
                        value: '${(d['hospital_lat'] as num).toStringAsFixed(5)}, '
                            '${(d['hospital_lng'] as num).toStringAsFixed(5)}',
                        mono: true,
                      ),
                    ],

                    // Emergency notes
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _DetailRow(
                        icon: Icons.notes,
                        label: 'Notes',
                        value: notes,
                      ),
                    ],

                    // Additional emergency details
                    if (emergency != null) ...[
                      ...emergency.entries
                          .where((e) => e.key != 'triage' && e.key != 'notes' && e.value != null)
                          .map((e) => Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _DetailRow(
                                  icon: Icons.info_outline,
                                  label: e.key.replaceAll('_', ' '),
                                  value: e.value.toString(),
                                ),
                              )),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'assigned':   return 'Assigned';
      case 'picked_up':  return 'Picked Up';
      case 'arrived':    return 'Arrived';
      case 'completed':  return 'Completed';
      case 'unknown':    return 'Unknown';
      default:           return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':  return AppColors.hospitalGreen;
      case 'arrived':    return AppColors.primary;
      case 'picked_up':  return AppColors.warningAmber;
      case 'assigned':   return AppColors.driverBlue;
      default:           return AppColors.textMuted;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'completed':  return Icons.check_circle_outline;
      case 'arrived':    return Icons.location_on;
      case 'picked_up':  return Icons.local_shipping;
      case 'assigned':   return Icons.assignment;
      default:           return Icons.help_outline;
    }
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final String label;
  final Color color;
  const _StatusChip({required this.status, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  const _DetailRow({required this.icon, required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontFamily: mono ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
