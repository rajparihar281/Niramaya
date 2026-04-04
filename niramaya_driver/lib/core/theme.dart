// ── Niramaya Driver — Premium Dark Theme ─────────────────────────────────────
// Design: Deep navy + Niramaya Teal (#00C6AE) — unified with patient app
// Typography: Outfit (headings) · Inter (body)
// Mood: Industrial-grade clarity, high-contrast outdoor readability

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color primary         = Color(0xFF00C6AE); // Niramaya teal
  static const Color primaryDark     = Color(0xFF009E8B);
  static const Color background      = Color(0xFF0A0E1A); // deep navy-black
  static const Color card            = Color(0xFF111827);
  static const Color cardElevated    = Color(0xFF1A2236);
  static const Color danger          = Color(0xFFFF3B5C);
  static const Color warning         = Color(0xFFFFB800);
  static const Color success         = Color(0xFF00E676);
  static const Color textPrimary     = Color(0xFFF0F4FF);
  static const Color textSecondary   = Color(0xFF8A9BB5);
  static const Color textMuted       = Color(0xFF4A5568);
  static const Color border          = Color(0xFF1E293B);
  static const Color borderFocused   = Color(0xFF00C6AE);
  static const Color shimmerBase     = Color(0xFF111827);
  static const Color shimmerHighlight = Color(0xFF1E293B);
  static const Color dutyOn          = Color(0xFF00C6AE);
  static const Color dutyOff         = Color(0xFF2D3748);
  static const Color alertBg         = Color(0xFFFF3B5C);

  // Symmetry tokens — shared with user app
  static const Color emergencyRed  = Color(0xFFFF3B5C);
  static const Color hospitalGreen = Color(0xFF1A9E6E);
  static const Color driverBlue    = Color(0xFF1A6FD4);
  static const Color warningAmber  = Color(0xFFE88B1A);
  static const Color surfaceDark   = Color(0xFF0F1117);
  static const Color textOnDark    = Color(0xFFF2F2F2);
  static const Color emergencyBlue = Color(0xFF0D47A1);

  // Gradient helpers
  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF00C6AE), Color(0xFF0EA5E9)],
    begin: Alignment.centerLeft,
    end:   Alignment.centerRight,
  );
  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF3B5C), Color(0xFFCC0033)],
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final outfit = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);
    final inter  = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness:   Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary:     AppColors.primary,
        secondary:   AppColors.primary,
        error:       AppColors.danger,
        surface:     AppColors.card,
        onPrimary:   AppColors.background,
        onSecondary: AppColors.background,
        onSurface:   AppColors.textPrimary,
        onError:     Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: outfit.titleLarge?.copyWith(
          color:      AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize:   20,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
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
          minimumSize: const Size(double.infinity, 54),
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
          minimumSize: const Size(double.infinity, 54),
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
        fillColor:      AppColors.cardElevated,
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
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
        hintStyle:  const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
        prefixIconColor: AppColors.textMuted,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:     AppColors.card,
        selectedItemColor:   AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type:      BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:   TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardElevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color:     AppColors.border,
        thickness: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.cardElevated;
        }),
        checkColor: WidgetStateProperty.all(AppColors.background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      textTheme: TextTheme(
        displayLarge:  outfit.displayLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        displayMedium: outfit.displayMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: outfit.headlineLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: outfit.headlineMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        headlineSmall:  outfit.headlineSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleLarge:     outfit.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium:    outfit.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        titleSmall:     outfit.titleSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        bodyLarge:  inter.bodyLarge?.copyWith(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium: inter.bodyMedium?.copyWith(color: AppColors.textPrimary, fontSize: 14),
        bodySmall:  inter.bodySmall?.copyWith(color: AppColors.textSecondary, fontSize: 12),
        labelLarge:  outfit.labelLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        labelMedium: inter.labelMedium?.copyWith(color: AppColors.textSecondary),
        labelSmall:  inter.labelSmall?.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}
