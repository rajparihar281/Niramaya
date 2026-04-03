class DispatchModel {
  final String dispatchId;
  final String hospital;
  final String distance;
  final double etaMinutes;
  final String patientIdSha;
  final int guardianAlertsEmitted;

  const DispatchModel({
    required this.dispatchId,
    required this.hospital,
    required this.distance,
    required this.etaMinutes,
    required this.patientIdSha,
    this.guardianAlertsEmitted = 0,
  });

  factory DispatchModel.fromJson(Map<String, dynamic> json) {
    return DispatchModel(
      dispatchId: json['dispatch_id'] as String,
      hospital: json['hospital'] as String,
      distance: json['distance'] as String,
      etaMinutes: (json['eta_minutes'] as num).toDouble(),
      patientIdSha: json['patient_id_sha'] as String? ?? '',
      guardianAlertsEmitted: json['guardian_alerts_emitted'] as int? ?? 0,
    );
  }
}

class DispatchStatusModel {
  final String status;
  final double lat;
  final double lng;

  const DispatchStatusModel({
    required this.status,
    required this.lat,
    required this.lng,
  });

  factory DispatchStatusModel.fromJson(Map<String, dynamic> json) {
    return DispatchStatusModel(
      status: json['status'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}
