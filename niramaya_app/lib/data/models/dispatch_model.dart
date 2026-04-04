class DispatchModel {
  final String dispatchId;
  final String hospital;
  final String distance;
  final double etaMinutes;
  final String patientIdSha;
  final int guardianAlertsEmitted;
  final String? driverId;
  // Symmetric map coordinates — written by Go backend, read by both apps
  final double? patientLat;
  final double? patientLng;
  final double? hospitalLat;
  final double? hospitalLng;

  const DispatchModel({
    required this.dispatchId,
    required this.hospital,
    required this.distance,
    required this.etaMinutes,
    required this.patientIdSha,
    this.guardianAlertsEmitted = 0,
    this.driverId,
    this.patientLat,
    this.patientLng,
    this.hospitalLat,
    this.hospitalLng,
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
      patientLat: (json['patient_lat'] as num?)?.toDouble(),
      patientLng: (json['patient_lng'] as num?)?.toDouble(),
      hospitalLat: (json['hospital_lat'] as num?)?.toDouble(),
      hospitalLng: (json['hospital_lng'] as num?)?.toDouble(),
    );
  }
}

class DispatchStatusModel {
  final String status;
  final String hospital;

  const DispatchStatusModel({
    required this.status,
    required this.hospital,
  });

  factory DispatchStatusModel.fromJson(Map<String, dynamic> json) {
    return DispatchStatusModel(
      status: json['status']?.toString() ?? '',
      hospital: json['hospital']?.toString() ?? '',
    );
  }
}
