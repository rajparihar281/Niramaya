// ── HospitalModel — maps public.hospitals table ───────────────────────────────

class HospitalModel {
  final String id;
  final String name;
  final String? address;
  final bool isActive;

  const HospitalModel({
    required this.id,
    required this.name,
    this.address,
    this.isActive = true,
  });

  factory HospitalModel.fromMap(Map<String, dynamic> m) {
    return HospitalModel(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      address: m['address']?.toString(),
      isActive: m['is_active'] != false, // defaults true if null
    );
  }
}
