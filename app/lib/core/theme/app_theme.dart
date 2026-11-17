import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const primary = Color(0xFF286047);
  static const primaryVariant = Color(0xFF153D2E);
  static const secondary = Color(0xFFCF6A49);
  static const background = Color(0xFFF5F5EF);
  static const surface = Color(0xFFFFFEFA);
  static const error = Color(0xFFAE3D37);
  static const onPrimary = Colors.white;
  static const onSurface = Color(0xFF20362B);
  static const muted = Color(0xFF626F66);
  static const line = Color(0xFFE1E6DC);
  static const lime = Color(0xFFDCE9AC);
  static const peach = Color(0xFFF3DDD0);
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32, xxl = 48;
}

class AppTheme {
  AppTheme._();
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DM Sans',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 36,
            height: 1.15,
            letterSpacing: -1.2,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface),
        headlineMedium: TextStyle(
            fontSize: 28,
            height: 1.2,
            letterSpacing: -.8,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface),
        titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -.4,
            color: AppColors.onSurface),
        titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface),
        bodyLarge:
            TextStyle(fontSize: 16, height: 1.6, color: AppColors.onSurface),
        bodyMedium:
            TextStyle(fontSize: 14, height: 1.5, color: AppColors.onSurface),
        bodySmall: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 24,
          centerTitle: false,
          titleTextStyle: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface)),
      cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.line))),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 50),
              shape: shape,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 16))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(48, 52),
              shape: shape)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: shape,
              side: const BorderSide(color: AppColors.line))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: shape),
      chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          labelStyle: const TextStyle(color: AppColors.muted),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary, linearTrackColor: AppColors.line),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryVariant,
          shape: shape),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.lime.withValues(alpha: .65),
          labelTextStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
    );
  }
}
