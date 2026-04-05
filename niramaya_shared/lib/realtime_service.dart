import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

/// Represents connection status of the realtime channels
enum RealtimeStatus { connected, reconnecting, disconnected }

// ─── Data Models ───────────────────────────────────────────────────────────

class DriverLocation {
  final String id;
  final LatLng? location;
  final DateTime updatedAt;

  DriverLocation({
    required this.id,
    this.location,
    required this.updatedAt,
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    LatLng? loc;
    final lat = (json['driver_lat'] as num?)?.toDouble();
    final lng = (json['driver_lng'] as num?)?.toDouble();
    if (lat != null && lng != null) loc = LatLng(lat, lng);
    return DriverLocation(
      id: json['id'] as String,
      location: loc,
      updatedAt: json['location_updated_at'] != null
          ? DateTime.parse(json['location_updated_at'])
          : DateTime.now(),
    );
  }
}

class DispatchUpdate {
  final String id;
  final String? patientId;
  final String? driverId;
  final String status;
  final double? patientLat;
  final double? patientLng;
  final double? hospitalLat;
  final double? hospitalLng;
  final String? hospitalName;
  final String? hospitalId;
  final DateTime createdAt;
  final DateTime updatedAt;

  DispatchUpdate({
    required this.id,
    this.patientId,
    this.driverId,
    required this.status,
    this.patientLat,
    this.patientLng,
    this.hospitalLat,
    this.hospitalLng,
    this.hospitalName,
    this.hospitalId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DispatchUpdate.fromJson(Map<String, dynamic> json) {
    return DispatchUpdate(
      id: json['id'] as String,
      patientId: json['patient_id'] as String?,
      driverId: json['driver_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      patientLat: (json['patient_lat'] as num?)?.toDouble(),
      patientLng: (json['patient_lng'] as num?)?.toDouble(),
      hospitalLat: (json['hospital_lat'] as num?)?.toDouble(),
      hospitalLng: (json['hospital_lng'] as num?)?.toDouble(),
      hospitalName: json['hospital_name'] as String?,
      hospitalId: json['hospital_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }
}

// ─── Realtime Service ────────────────────────────────────────────────────────

class RealtimeService {
  final SupabaseClient _client;
  
  final StreamController<RealtimeStatus> _statusController = StreamController<RealtimeStatus>.broadcast();
  RealtimeStatus _currentStatus = RealtimeStatus.disconnected;

  // Track channels to prevent duplication
  final Map<String, RealtimeChannel> _activeChannels = {};
  // Track streams so multiple listeners can share the same instance
  final Map<String, Stream<dynamic>> _activeStreams = {};

  RealtimeService(this._client) {
    _statusController.add(_currentStatus);
  }

  Stream<RealtimeStatus> get statusStream => _statusController.stream;

  void _updateStatus(RealtimeStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  /// Subscribe to a driver's live GPS telemetry
  Stream<DriverLocation> driverLocationStream(String driverId) {
    final cacheKey = 'driver_$driverId';
    if (_activeStreams.containsKey(cacheKey)) {
      return _activeStreams[cacheKey] as Stream<DriverLocation>;
    }

    final controller = StreamController<DriverLocation>.broadcast();
    int backoffSeconds = 1;
    Timer? reconnectTimer;
    RealtimeChannel? channel;
    bool isFirstConnect = true;

    Future<void> fetchLatestAndResume() async {
      try {
        final res = await _client
            .from('drivers')
            .select('id, driver_lat, driver_lng, location_updated_at')
            .eq('id', driverId)
            .maybeSingle();
        if (res != null) controller.add(DriverLocation.fromJson(res));
      } catch (_) {}
    }

    void connect() {
      channel = _client.channel('public:drivers:id=eq.$driverId');
      
      channel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'drivers',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: driverId),
        callback: (payload) {
          controller.add(DriverLocation.fromJson(payload.newRecord));
        },
      ).subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          backoffSeconds = 1;
          _updateStatus(RealtimeStatus.connected);
          
          // Re-fetch via REST on connect to fill any gap since disconnect
          // But omit if this is the very first connect and we haven't lost data
          if (!isFirstConnect) {
            await fetchLatestAndResume();
          }
          isFirstConnect = false;

        } else if (status == RealtimeSubscribeStatus.closed || status == RealtimeSubscribeStatus.channelError) {
          _updateStatus(RealtimeStatus.reconnecting);
          reconnectTimer?.cancel();
          
          if (backoffSeconds > 30) {
            _updateStatus(RealtimeStatus.disconnected);
            backoffSeconds = 30; // cap at 30 seconds
          }
          
          reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
            if (backoffSeconds < 30) backoffSeconds *= 2;
            _client.removeChannel(channel!);
            connect();
          });
        }
      });
      _activeChannels[cacheKey] = channel!;
    }

    controller.onListen = () {
      connect();
      fetchLatestAndResume(); // Initial baseline fetch
    };

    controller.onCancel = () {
      reconnectTimer?.cancel();
      if (channel != null) {
        _client.removeChannel(channel!);
      }
      _activeChannels.remove(cacheKey);
      _activeStreams.remove(cacheKey);
      controller.close();
    };

    _activeStreams[cacheKey] = controller.stream;
    return controller.stream;
  }

  /// Subscribe to a dispatch's state changes
  Stream<DispatchUpdate> dispatchStream(String dispatchId) {
    final cacheKey = 'dispatch_$dispatchId';
    if (_activeStreams.containsKey(cacheKey)) {
      return _activeStreams[cacheKey] as Stream<DispatchUpdate>;
    }

    final controller = StreamController<DispatchUpdate>.broadcast();
    int backoffSeconds = 1;
    Timer? reconnectTimer;
    RealtimeChannel? channel;
    bool isFirstConnect = true;

    Future<void> fetchLatestAndResume() async {
      try {
        final res = await _client.from('dispatches').select().eq('id', dispatchId).maybeSingle();
        if (res != null) {
          controller.add(DispatchUpdate.fromJson(res));
        }
      } catch (_) {}
    }

    void connect() {
      channel = _client.channel('public:dispatches:id=eq.$dispatchId');
      
      channel!.onPostgresChanges(
        event: PostgresChangeEvent.all, // Listen to INSERT/UPDATE
        schema: 'public',
        table: 'dispatches',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: dispatchId),
        callback: (payload) {
          controller.add(DispatchUpdate.fromJson(payload.newRecord));
        },
      ).subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          backoffSeconds = 1;
          _updateStatus(RealtimeStatus.connected);
          
          if (!isFirstConnect) {
            await fetchLatestAndResume();
          }
          isFirstConnect = false;

        } else if (status == RealtimeSubscribeStatus.closed || status == RealtimeSubscribeStatus.channelError) {
          _updateStatus(RealtimeStatus.reconnecting);
          reconnectTimer?.cancel();
          
          if (backoffSeconds > 30) {
            _updateStatus(RealtimeStatus.disconnected);
            backoffSeconds = 30; // cap at 30 seconds
          }
          
          reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
            if (backoffSeconds < 30) backoffSeconds *= 2;
            _client.removeChannel(channel!);
            connect();
          });
        }
      });
      _activeChannels[cacheKey] = channel!;
    }

    controller.onListen = () {
      connect();
      fetchLatestAndResume(); // Initial baseline fetch
    };

    controller.onCancel = () {
      reconnectTimer?.cancel();
      if (channel != null) {
        _client.removeChannel(channel!);
      }
      _activeChannels.remove(cacheKey);
      _activeStreams.remove(cacheKey);
      controller.close();
    };

    _activeStreams[cacheKey] = controller.stream;
    return controller.stream;
  }

  void dispose() {
    _statusController.close();
    for (var channel in _activeChannels.values) {
      _client.removeChannel(channel);
    }
    _activeChannels.clear();
    _activeStreams.clear();
  }
}

// ─── Riverpod Providers ──────────────────────────────────────────────────────

final realTimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(Supabase.instance.client);
  ref.onDispose(() => service.dispose());
  return service;
});

final realtimeStatusProvider = StreamProvider<RealtimeStatus>((ref) {
  return ref.watch(realTimeServiceProvider).statusStream;
});
