import 'dart:convert';
import 'package:crypto/crypto.dart';

class ShaUtils {
  ShaUtils._();

  /// Produces SHA-256 hash of the given [input].
  /// Used to hash ABHA IDs → patient_hash for hospital_access table.
  static String sha256Hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
