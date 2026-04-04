// ── Niramaya App — Premium Dark Theme ────────────────────────────────────────
// Design: Deep navy + Niramaya Teal (#00C6AE) accent
// Typography: Outfit (headings) · Inter (body)
// Mood: Medical-grade trust, glassy surfaces, vibrant accents

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Core palette — mirrored from driver app for unified branding
  static const Color primary       = Color(0xFF00C6AE); // Niramaya teal
  static const Color primaryDark   = Color(0xFF009E8B);
  static const Color accent        = Color(0xFF38BDF8); // sky-400
  static const Color emergency     = Color(0xFFFF3B5C); // vivid red
  static const Color background    = Color(0xFF0A0E1A); // deep navy-black
  static const Color surface       = Color(0xFF111827); // card surface
  static const Color surfaceElevated = Color(0xFF1A2236); // elevated card
  static const Color textPrimary   = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF8A9BB5);
  static const Color textMuted     = Color(0xFF4A5568);
  static const Color success       = Color(0xFF00E676);
  static const Color warning       = Color(0xFFFFB800);
  static const Color divider       = Color(0xFF1E293B);
  static const Color inputBorder   = Color(0xFF1E293B);
  static const Color border        = Color(0xFF1E293B);

  // Legacy compat
  static const Color cardBackground = surface;
  static const Color emergencyRed   = emergency;
  static const Color hospitalGreen  = Color(0xFF1A9E6E);
  static const Color driverBlue     = Color(0xFF1A6FD4);
  static const Color warningAmber   = Color(0xFFE88B1A);
  static const Color surfaceDark    = Color(0xFF0F1117);
  static const Color textOnDark     = Color(0xFFF2F2F2);
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final outfit = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);
    final inter  = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary:     AppColors.primary,
        secondary:   AppColors.accent,
        error:       AppColors.emergency,
        surface:     AppColors.surface,
        onPrimary:   AppColors.background,
        onSecondary: Colors.white,
        onSurface:   AppColors.textPrimary,
        onError:     Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: outfit.titleLarge?.copyWith(
          color:       AppColors.textPrimary,
          fontWeight:  FontWeight.w700,
          fontSize:    20,
          letterSpacing: 0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          minimumSize:     const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: outfit.labelLarge?.copyWith(
            fontWeight:    FontWeight.w700,
            fontSize:      16,
            letterSpacing: 0.5,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize:     const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: outfit.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize:   16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:         true,
        fillColor:      AppColors.surfaceElevated,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emergency),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emergency, width: 2),
        ),
        hintStyle:    const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle:   const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        errorStyle:   const TextStyle(color: AppColors.emergency, fontSize: 12),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        width: 285,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:     AppColors.surface,
        selectedItemColor:   AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type:      BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:   TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      dividerTheme: const DividerThemeData(
        color:     AppColors.divider,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.surfaceElevated;
        }),
        checkColor: WidgetStateProperty.all(AppColors.background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      textTheme: TextTheme(
        displayLarge: outfit.displayLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        displayMedium: outfit.displayMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: outfit.headlineLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: outfit.headlineMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        headlineSmall: outfit.headlineSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleLarge: outfit.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium: outfit.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        titleSmall: outfit.titleSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        bodyLarge: inter.bodyLarge?.copyWith(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium: inter.bodyMedium?.copyWith(color: AppColors.textPrimary, fontSize: 14),
        bodySmall: inter.bodySmall?.copyWith(color: AppColors.textSecondary, fontSize: 12),
        labelLarge: outfit.labelLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        labelMedium: inter.labelMedium?.copyWith(color: AppColors.textSecondary),
        labelSmall: inter.labelSmall?.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  // Keep lightTheme alias for backward compat — points to dark
  static ThemeData get lightTheme => darkTheme;
}
