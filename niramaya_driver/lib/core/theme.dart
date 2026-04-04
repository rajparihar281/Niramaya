import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color primary        = Color(0xFF00C6AE);
  static const Color primaryDark    = Color(0xFF009E8B);
  static const Color background     = Color(0xFFFFFFFF);
  static const Color card           = Color(0xFFF8FAFB);
  static const Color cardElevated   = Color(0xFFEFF3F6);
  static const Color danger         = Color(0xFFE53935);
  static const Color warning        = Color(0xFFF59E0B);
  static const Color success        = Color(0xFF00897B);
  static const Color textPrimary    = Color(0xFF0D1B2E);
  static const Color textSecondary  = Color(0xFF4A6080);
  static const Color textMuted      = Color(0xFF8FA3B8);
  static const Color border         = Color(0xFFE2EAF0);
  static const Color borderFocused  = Color(0xFF00C6AE);
  static const Color dutyOn         = Color(0xFF00C6AE);
  static const Color dutyOff        = Color(0xFFCBD5E1);
  static const Color alertBg        = Color(0xFFE53935);

  // Shared map tokens
  static const Color emergencyRed   = Color(0xFFE53935);
  static const Color hospitalGreen  = Color(0xFF00897B);
  static const Color driverBlue     = Color(0xFF1565C0);
  static const Color warningAmber   = Color(0xFFF59E0B);
  static const Color surfaceDark    = Color(0xFF0D1B2E);
  static const Color textOnDark     = Color(0xFFF2F2F2);
  static const Color emergencyBlue  = Color(0xFF0D47A1);

  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF00C6AE), Color(0xFF0EA5E9)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => lightTheme;

  static ThemeData get lightTheme {
    final outfit = GoogleFonts.outfitTextTheme(ThemeData.light().textTheme);
    final inter  = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary:     AppColors.primary,
        secondary:   AppColors.primary,
        error:       AppColors.danger,
        surface:     AppColors.card,
        onPrimary:   Colors.white,
        onSecondary: Colors.white,
        onSurface:   AppColors.textPrimary,
        onError:     Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: outfit.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: outfit.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 54),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderFocused, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
        prefixIconColor: AppColors.textMuted,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: const TextStyle(color: AppColors.textOnDark, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.primary : AppColors.card),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      textTheme: TextTheme(
        displayLarge:  outfit.displayLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        displayMedium: outfit.displayMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: outfit.headlineLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: outfit.headlineMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        headlineSmall:  outfit.headlineSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleLarge:  outfit.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium: outfit.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        titleSmall:  outfit.titleSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        bodyLarge:   inter.bodyLarge?.copyWith(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium:  inter.bodyMedium?.copyWith(color: AppColors.textPrimary, fontSize: 14),
        bodySmall:   inter.bodySmall?.copyWith(color: AppColors.textSecondary, fontSize: 12),
        labelLarge:  outfit.labelLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        labelMedium: inter.labelMedium?.copyWith(color: AppColors.textSecondary),
        labelSmall:  inter.labelSmall?.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}
