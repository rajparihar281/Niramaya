// ── SHA Utils — Display-only hash truncation ────────────────────────────────
// The driver app NEVER generates patient hashes. It only displays truncated
// versions of the SHA-256 hash received from dispatches.patient_id.

class ShaUtils {
  ShaUtils._();

  /// Truncate a SHA-256 hash to the first [length] characters for display.
  /// Example: "a3f2b1c4e5d6f7a8..." → "#a3f2b1c4"
  static String truncateHash(String hash, {int length = 8}) {
    if (hash.isEmpty) return '#--------';
    final clean = hash.replaceAll(RegExp(r'[^a-fA-F0-9]'), '');
    if (clean.isEmpty) return '#--------';
    final truncated = clean.length >= length
        ? clean.substring(0, length)
        : clean.padRight(length, '-');
    return '#$truncated';
  }
}
