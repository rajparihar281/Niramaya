class DispatchModel {
  final String dispatchId;
  final String hospital;
  final String distance;
  final double etaMinutes;
  final String patientIdSha;
  final int guardianAlertsEmitted;
  final String? driverId;
  final String? status;
  final double? patientLat;
  final double? patientLng;
  final double? hospitalLat;
  final double? hospitalLng;
  // Live OSRM metrics written by driver app (TEXT columns in schema)
  final String? liveDistance;
  final String? liveEta;
  // Driver info
  final String? driverName;
  final double? driverRating;
  final String? plateNumber;
  // Triage — from required_dept or emergency_details.triage JSONB
  final String? requiredDept;

  const DispatchModel({
    required this.dispatchId,
    required this.hospital,
    required this.distance,
    required this.etaMinutes,
    required this.patientIdSha,
    this.guardianAlertsEmitted = 0,
    this.driverId,
    this.status,
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
      dispatchId: json['dispatch_id']?.toString() ?? '',
      hospital: json['hospital']?.toString() ?? '',
      distance: json['distance']?.toString() ?? '',
      etaMinutes: (json['eta_minutes'] as num?)?.toDouble() ?? 0,
      patientIdSha: json['patient_id_sha']?.toString() ?? '',
      guardianAlertsEmitted: json['guardian_alerts_emitted'] as int? ?? 0,
      driverId: json['driver_id']?.toString(),
      status: json['status']?.toString(),
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
}

class DispatchStatusModel {
  final String status;
  final String hospital;
  // Live fields from realtime
  final String? liveEta;
  final String? liveDistance;

  const DispatchStatusModel({
    required this.status,
    required this.hospital,
    this.liveEta,
    this.liveDistance,
  });

  factory DispatchStatusModel.fromJson(Map<String, dynamic> json) {
    return DispatchStatusModel(
      status: json['status']?.toString() ?? '',
      hospital: json['hospital']?.toString() ?? '',
      liveEta: json['live_eta']?.toString(),
      liveDistance: json['live_distance']?.toString(),
    );
  }
}
