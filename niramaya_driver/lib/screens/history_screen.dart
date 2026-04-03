// ── History Screen — Dispatch history with infinite scroll ──────────────────

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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMore();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
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
          .from('driver_dispatch_history')
          .select()
          .eq('driver_user_id', profile.id)
          .order('created_at', ascending: false)
          .range(from, to);

      final rows = List<Map<String, dynamic>>.from(result);

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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('DISPATCH HISTORY'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        child: _dispatches.isEmpty && !_isLoading
            ? _buildEmpty()
            : ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _dispatches.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _dispatches.length) {
                    return _buildLoader();
                  }
                  return _buildDispatchCard(_dispatches[index]);
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
          Icon(
            Icons.history,
            color: AppColors.textMuted.withValues(alpha: 0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No dispatch history yet',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
            ),
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
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildDispatchCard(Map<String, dynamic> data) {
    final createdAt =
        DateTime.tryParse(data['created_at']?.toString() ?? '') ??
            DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(createdAt);
    final patientHash =
        ShaUtils.truncateHash(data['patient_id']?.toString() ?? '');
    final hospitalName =
        data['hospital_name']?.toString() ?? 'Unknown Hospital';
    final status = data['status']?.toString() ?? 'unknown';

    // Calculate duration
    String durationStr = '—';
    final pickup =
        DateTime.tryParse(data['pickup_confirmed_at']?.toString() ?? '');
    final dropoff =
        DateTime.tryParse(data['dropoff_confirmed_at']?.toString() ?? '');
    if (pickup != null && dropoff != null) {
      final dur = dropoff.difference(pickup);
      if (dur.inMinutes < 60) {
        durationStr = '${dur.inMinutes} min';
      } else {
        durationStr = '${dur.inHours}h ${dur.inMinutes % 60}m';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5, right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusDotColor(status),
            ),
          ),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date + Hospital
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        hospitalName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _statusChip(status),
                  ],
                ),
                const SizedBox(height: 6),

                // Patient hash + duration
                Row(
                  children: [
                    Text(
                      patientHash,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Duration: $durationStr',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = AppColors.success;
        label = '✅ completed';
        break;
      case 'arrived':
        color = AppColors.primary;
        label = 'arrived';
        break;
      case 'en_route':
        color = AppColors.warning;
        label = 'en route';
        break;
      case 'assigned':
        color = AppColors.warning;
        label = 'assigned';
        break;
      default:
        color = AppColors.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _statusDotColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'arrived':
        return AppColors.primary;
      case 'en_route':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }
}
