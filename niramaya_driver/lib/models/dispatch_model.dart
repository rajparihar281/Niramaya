// ── DispatchModel — Maps dispatches table ────────────────────────────────────

enum DispatchStatus { assigned, enRoute, arrived, completed, unknown }

class DispatchModel {
  final String id;
  final String patientId;
  final String? driverId;
  final String? ambulanceId;
  final String? hospitalId;
  final String? hospitalName;
  final DispatchStatus status;
  final DateTime createdAt;
  final DateTime? pickupConfirmedAt;
  final DateTime? dropoffConfirmedAt;
  final String? driverNotes;
  final DateTime? alertSentAt;
  final double? patientLat;
  final double? patientLng;
  final double? hospitalLat;
  final double? hospitalLng;

  const DispatchModel({
    required this.id,
    required this.patientId,
    this.driverId,
    this.ambulanceId,
    this.hospitalId,
    this.hospitalName,
    required this.status,
    required this.createdAt,
    this.pickupConfirmedAt,
    this.dropoffConfirmedAt,
    this.driverNotes,
    this.alertSentAt,
    this.patientLat,
    this.patientLng,
    this.hospitalLat,
    this.hospitalLng,
  });

  factory DispatchModel.fromJson(Map<String, dynamic> json) {
    return DispatchModel(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      driverId: json['driver_id']?.toString(),
      ambulanceId: json['ambulance_id']?.toString(),
      hospitalId: json['hospital_id']?.toString(),
      hospitalName: json['hospital_name']?.toString(),
      status: _parseStatus(json['status']?.toString()),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      pickupConfirmedAt:
          DateTime.tryParse(json['pickup_confirmed_at']?.toString() ?? ''),
      dropoffConfirmedAt:
          DateTime.tryParse(json['dropoff_confirmed_at']?.toString() ?? ''),
      driverNotes: json['driver_notes']?.toString(),
      alertSentAt:
          DateTime.tryParse(json['alert_sent_at']?.toString() ?? ''),
      patientLat: (json['patient_lat'] as num?)?.toDouble(),
      patientLng: (json['patient_lng'] as num?)?.toDouble(),
      hospitalLat: (json['hospital_lat'] as num?)?.toDouble(),
      hospitalLng: (json['hospital_lng'] as num?)?.toDouble(),
    );
  }

  /// Duration between pickup → dropoff, or null if incomplete
  Duration? get tripDuration {
    if (pickupConfirmedAt == null || dropoffConfirmedAt == null) return null;
    return dropoffConfirmedAt!.difference(pickupConfirmedAt!);
  }

  /// Human-readable trip duration: "16 min" or "1h 23m"
  String get tripDurationDisplay {
    final dur = tripDuration;
    if (dur == null) return '—';
    if (dur.inMinutes < 60) return '${dur.inMinutes} min';
    final h = dur.inHours;
    final m = dur.inMinutes % 60;
    return '${h}h ${m}m';
  }

  /// Elapsed time since dispatch was created
  Duration get elapsed => DateTime.now().difference(createdAt);

  /// Formatted elapsed: "00:04:32"
  String get elapsedDisplay {
    final d = elapsed;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get statusDisplay {
    switch (status) {
      case DispatchStatus.assigned:
        return 'ASSIGNED';
      case DispatchStatus.enRoute:
        return 'EN ROUTE';
      case DispatchStatus.arrived:
        return 'ARRIVED';
      case DispatchStatus.completed:
        return 'COMPLETED';
      case DispatchStatus.unknown:
        return 'UNKNOWN';
    }
  }

  static DispatchStatus _parseStatus(String? s) {
    switch (s) {
      case 'assigned':
        return DispatchStatus.assigned;
      case 'en_route':
        return DispatchStatus.enRoute;
      case 'arrived':
        return DispatchStatus.arrived;
      case 'completed':
        return DispatchStatus.completed;
      default:
        return DispatchStatus.unknown;
    }
  }

  static String statusToDb(DispatchStatus s) {
    switch (s) {
      case DispatchStatus.assigned:
        return 'assigned';
      case DispatchStatus.enRoute:
        return 'en_route';
      case DispatchStatus.arrived:
        return 'arrived';
      case DispatchStatus.completed:
        return 'completed';
      case DispatchStatus.unknown:
        return 'unknown';
    }
  }
}
