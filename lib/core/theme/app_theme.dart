import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../providers/shared_preferences_provider.dart';

// ── Theme Mode Provider ───────────────────────────────────────────────────────

/// Persists and exposes the current [ThemeMode].
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) : super(ThemeMode.light) {
    final isDark = _prefs.getBool(AppConstants.prefIsDarkMode) ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void toggle() {
    final isDark = state == ThemeMode.dark;
    state = isDark ? ThemeMode.light : ThemeMode.dark;
    _prefs.setBool(AppConstants.prefIsDarkMode, !isDark);
  }

  bool get isDark => state == ThemeMode.dark;
}

// ── Theme Definition ──────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  // ── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.success,
        error: AppColors.danger,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _buildTextTheme(AppColors.textPrimary),
      appBarTheme: _buildAppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      cardTheme: _buildCardTheme(AppColors.surface, AppColors.border),
      elevatedButtonTheme: _buildElevatedButtonTheme(AppColors.primary),
      outlinedButtonTheme: _buildOutlinedButtonTheme(AppColors.primary),
      inputDecorationTheme: _buildInputDecoration(
        fillColor: AppColors.surfaceVariant,
        borderColor: AppColors.border,
        focusBorderColor: AppColors.primary,
        labelColor: AppColors.textSecondary,
        hintColor: AppColors.textDisabled,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        elevation: 12,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        elevation: 8,
      ),
    );
  }

  // ── Dark Theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    const primaryDark = Color(0xFF60A5FA); // Lighter blue for dark bg

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: primaryDark,
        onPrimary: Colors.black,
        secondary: AppColors.success,
        error: AppColors.danger,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: _buildTextTheme(AppColors.darkTextPrimary),
      appBarTheme: _buildAppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
      ),
      cardTheme: _buildCardTheme(AppColors.darkSurface, AppColors.darkBorder),
      elevatedButtonTheme: _buildElevatedButtonTheme(primaryDark),
      outlinedButtonTheme: _buildOutlinedButtonTheme(primaryDark),
      inputDecorationTheme: _buildInputDecoration(
        fillColor: AppColors.darkSurfaceVariant,
        borderColor: AppColors.darkBorder,
        focusBorderColor: primaryDark,
        labelColor: AppColors.darkTextSecondary,
        hintColor: AppColors.darkBorder,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: Colors.black,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: primaryDark,
        unselectedItemColor: AppColors.darkTextSecondary,
        elevation: 12,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        elevation: 8,
      ),
    );
  }

  // ── Shared Component Builders ─────────────────────────────────────────────

  static TextTheme _buildTextTheme(Color base) {
    return GoogleFonts.poppinsTextTheme().copyWith(
      displayLarge:  GoogleFonts.poppins(fontSize: 57, fontWeight: FontWeight.w700, color: base),
      displayMedium: GoogleFonts.poppins(fontSize: 45, fontWeight: FontWeight.w700, color: base),
      displaySmall:  GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w600, color: base),
      headlineLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: base),
      headlineMedium:GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w600, color: base),
      headlineSmall: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: base),
      titleLarge:    GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: base),
      titleMedium:   GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: base),
      titleSmall:    GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: base),
      bodyLarge:     GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400, color: base),
      bodyMedium:    GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, color: base),
      bodySmall:     GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: base.withValues(alpha: 0.7)),
      labelLarge:    GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: base),
      labelMedium:   GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: base),
      labelSmall:    GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: base),
    );
  }

  static AppBarTheme _buildAppBarTheme({
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: foregroundColor,
      ),
      iconTheme: IconThemeData(color: foregroundColor),
    );
  }

  static CardTheme _buildCardTheme(Color color, Color borderColor) {
    return CardTheme(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      margin: EdgeInsets.zero,
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(Color primary) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(Color primary) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: BorderSide(color: primary, width: 1.5),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static InputDecorationTheme _buildInputDecoration({
    required Color fillColor,
    required Color borderColor,
    required Color focusBorderColor,
    required Color labelColor,
    required Color hintColor,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor, width: 1),
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: focusBorderColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      labelStyle: GoogleFonts.poppins(color: labelColor, fontSize: 14),
      hintStyle: GoogleFonts.poppins(color: hintColor, fontSize: 14),
      errorStyle: GoogleFonts.poppins(
        color: AppColors.danger,
        fontSize: 12,
      ),
    );
  }
}
