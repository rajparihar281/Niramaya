enum DispatchStatus { assigned, pickedUp, arrived, completed, unknown }

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
  // Live OSRM metrics written by driver app every 10s
  final String? liveDistance;
  final String? liveEta;
  // Driver info (enriched from drivers table)
  final String? driverName;
  final double? driverRating;
  final String? plateNumber;
  // Triage
  final String? requiredDept;

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
    this.liveDistance,
    this.liveEta,
    this.driverName,
    this.driverRating,
    this.plateNumber,
    this.requiredDept,
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
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      pickupConfirmedAt: DateTime.tryParse(json['pickup_confirmed_at']?.toString() ?? ''),
      dropoffConfirmedAt: DateTime.tryParse(json['dropoff_confirmed_at']?.toString() ?? ''),
      driverNotes: json['driver_notes']?.toString(),
      alertSentAt: DateTime.tryParse(json['alert_sent_at']?.toString() ?? ''),
      patientLat: (json['patient_lat'] as num?)?.toDouble(),
      patientLng: (json['patient_lng'] as num?)?.toDouble(),
      hospitalLat: (json['hospital_lat'] as num?)?.toDouble(),
      hospitalLng: (json['hospital_lng'] as num?)?.toDouble(),
      liveDistance: json['live_distance']?.toString(),
      liveEta: json['live_eta']?.toString(),
      driverName: json['driver_name']?.toString(),
      driverRating: (json['driver_rating'] as num?)?.toDouble(),
      plateNumber: json['plate_number']?.toString(),
      requiredDept: json['required_dept']?.toString()
          ?? (json['emergency_details'] as Map?)?['triage']?.toString(),
    );
  }

  Duration? get tripDuration {
    if (pickupConfirmedAt == null || dropoffConfirmedAt == null) return null;
    return dropoffConfirmedAt!.difference(pickupConfirmedAt!);
  }

  String get tripDurationDisplay {
    final dur = tripDuration;
    if (dur == null) return '—';
    if (dur.inMinutes < 60) return '${dur.inMinutes} min';
    return '${dur.inHours}h ${dur.inMinutes % 60}m';
  }

  Duration get elapsed => DateTime.now().difference(createdAt);

  String get elapsedDisplay {
    final d = elapsed;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get statusDisplay {
    switch (status) {
      case DispatchStatus.assigned:  return 'ASSIGNED';
      case DispatchStatus.pickedUp:  return 'EN ROUTE';
      case DispatchStatus.arrived:   return 'ARRIVED';
      case DispatchStatus.completed: return 'COMPLETED';
      case DispatchStatus.unknown:   return 'UNKNOWN';
    }
  }

  static DispatchStatus _parseStatus(String? s) {
    switch (s) {
      case 'assigned':  return DispatchStatus.assigned;
      case 'picked_up': return DispatchStatus.pickedUp;
      case 'arrived':   return DispatchStatus.arrived;
      case 'completed': return DispatchStatus.completed;
      default:          return DispatchStatus.unknown;
    }
  }

  static String statusToDb(DispatchStatus s) {
    switch (s) {
      case DispatchStatus.assigned:  return 'assigned';
      case DispatchStatus.pickedUp:  return 'picked_up';
      case DispatchStatus.arrived:   return 'arrived';
      case DispatchStatus.completed: return 'completed';
      case DispatchStatus.unknown:   return 'unknown';
    }
  }
}
