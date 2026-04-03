import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../data/models/medication_model.dart';
import '../data/supabase_client.dart';
import '../services/vision_service.dart';

class MedicationState {
  final bool isLoading;
  final bool isScanning;
  final List<MedicationModel> medications;
  final String? error;

  const MedicationState({
    this.isLoading = false,
    this.isScanning = false,
    this.medications = const [],
    this.error,
  });

  MedicationState copyWith({
    bool? isLoading,
    bool? isScanning,
    List<MedicationModel>? medications,
    String? error,
  }) {
    return MedicationState(
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      medications: medications ?? this.medications,
      error: error,
    );
  }
}

class MedicationNotifier extends StateNotifier<MedicationState> {
  final ImagePicker _picker = ImagePicker();

  MedicationNotifier() : super(const MedicationState());

  /// Fetch user medications from Supabase
  Future<void> fetchMedications(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await SupabaseClientHelper.client
          .from('patient_medications')
          .select()
          .eq('user_id', userId)
          .order('scanned_at', ascending: false);

      final meds = (data as List).map((dynamic json) {
        return MedicationModel.fromJson(json as Map<String, dynamic>);
      }).toList();

      state = state.copyWith(isLoading: false, medications: meds);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Launch Camera and Scan Medicine with Gemini
  Future<bool> scanAndSaveMedicine(String userId) async {
    state = state.copyWith(isScanning: true, error: null);
    try {
      // 1. Take Photo
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Compress for faster API upload
      );

      if (image == null) {
        // User cancelled camera
        state = state.copyWith(isScanning: false);
        return false;
      }

      final file = File(image.path);

      // 2. Identify with Gemini
      final medModel = await VisionService.scanMedicine(file, userId);

      // 3. Save to Supabase
      final response = await SupabaseClientHelper.client
          .from('patient_medications')
          .insert(medModel.toJson())
          .select()
          .single();

      final newMed = MedicationModel.fromJson(response);

      // 4. Update UI State
      state = state.copyWith(
        isScanning: false,
        medications: [newMed, ...state.medications],
      );

      // Clean up file if needed
      if (await file.exists()) {
        await file.delete();
      }

      return true;
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e.toString());
      return false;
    }
  }

  // Delete medication
  Future<bool> deleteMedication(String medId) async {
    try {
      await SupabaseClientHelper.client
          .from('patient_medications')
          .delete()
          .eq('id', medId);

      state = state.copyWith(
        medications: state.medications.where((m) => m.id != medId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final medicationProvider =
    StateNotifierProvider<MedicationNotifier, MedicationState>(
  (ref) => MedicationNotifier(),
);
