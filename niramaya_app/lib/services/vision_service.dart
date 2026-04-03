import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants.dart';
import '../data/models/medication_model.dart';

class VisionService {
  static final _model = GenerativeModel(
    model: 'gemini-1.5-flash-latest',
    apiKey: AppConstants.geminiApiKey,
  );

  static Future<MedicationModel> scanMedicine(File imageFile, String userId) async {
    final mimeType = _getMimeType(imageFile.path);
    final bytes = await imageFile.readAsBytes();

    final prompt = TextPart('''
Identify this medicine. Return ONLY a raw JSON object with no markdown formatting or blockquotes. Use exactly these keys:
{
  "name": "The actual name of the medicine",
  "dosage": "Strength/Dosage (e.g. 500mg)",
  "usage": "Brief instructions on what it is used for",
  "precautions": "Any major warnings"
}
''');
    final imagePart = DataPart(mimeType, bytes);

    try {
      final response = await _model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      var text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw Exception("Failed to recognize medicine (Empty response).");
      }

      // Strip markdown blockquotes if gemini still adds them despite instructions
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();

      final jsonMap = jsonDecode(text) as Map<String, dynamic>;
      
      // Merge with userId before passing to fromJson
      jsonMap['user_id'] = userId;
      
      return MedicationModel.fromJson(jsonMap);
    } catch (e) {
      throw Exception('Failed to identify medicine: $e');
    }
  }

  static String _getMimeType(String path) {
    if (path.toLowerCase().endsWith('.png')) return 'image/png';
    if (path.toLowerCase().endsWith('.webp')) return 'image/webp';
    return 'image/jpeg'; // Default for jpg/jpeg
  }
}
