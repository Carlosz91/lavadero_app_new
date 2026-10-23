import 'package:flutter/material.dart';

/// Paleta de la app. Identidad "Agua": cian/teal para la marca, neutros
/// pizarra. Los colores semánticos son constantes; los neutros dependen del
/// brillo activo y se ajustan con [AppColors.apply] al alternar claro/oscuro.
class AppColors {
  static Brightness _brightness = Brightness.light;

  static bool get isDark => _brightness == Brightness.dark;

  /// Aplica el brillo activo. Debe llamarse antes de reconstruir la UI
  /// (ThemeController lo hace junto al ThemeMode de MaterialApp).
  static void apply(Brightness brightness) => _brightness = brightness;

  // ── Marca y estados (constantes en ambos modos) ──
  static const Color primary = Color(0xFF0891B2); // cian 600 — agua/limpieza
  static const Color primaryLight = Color(0xFF22D3EE); // cian 400 (brillo en dark)
  static const Color primaryDark = Color(0xFF155E75); // cian 800
  static const Color error = Color(0xFFDC2626); // rojo 600
  static const Color success = Color(0xFF10B981); // esmeralda 500
  static const Color warning = Color(0xFFF59E0B); // ámbar 500

  // ── Neutros según brillo ──
  static Color get surface => isDark ? const Color(0xFF14202F) : const Color(0xFFFFFFFF);
  static Color get background => isDark ? const Color(0xFF0B1421) : const Color(0xFFF4F8FA);
  static Color get textPrimary => isDark ? const Color(0xFFEAF2F8) : const Color(0xFF0F172A);
  static Color get textSecondary => isDark ? const Color(0xFF8FA3B8) : const Color(0xFF64748B);
  static Color get textHint => isDark ? const Color(0xFF5E7285) : const Color(0xFF94A3B8);
  static Color get border => isDark ? const Color(0xFF28394A) : const Color(0xFFE2E8F0);
  static Color get divider => isDark ? const Color(0xFF1C2836) : const Color(0xFFEFF5F8);
  static Color get cardBackground => isDark ? const Color(0xFF14202F) : const Color(0xFFFFFFFF);
  static Color get inputFill => isDark ? const Color(0xFF0F1A28) : const Color(0xFFF7FAFC);
}

/// Tipografías del sistema de diseño. Se resuelven contra la paleta activa.
class AppTextStyles {
  static const String _fontFamily = 'Roboto';

  static TextStyle get h1 => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static TextStyle get h2 => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static TextStyle get h3 => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  /// Número destacado (montos, conteos) con jerarquía superior.
  static TextStyle get stat => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle get body => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodySmall => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  static TextStyle get caption => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    color: AppColors.textHint,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static TextStyle get button => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  static TextStyle get input => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    color: AppColors.textPrimary,
  );

  static TextStyle get whiteButton => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.3,
  );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final brand = isDark ? AppColors.primaryLight : AppColors.primary;

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: isDark ? AppColors.primaryLight : AppColors.primary,
        secondary: isDark
            ? AppColors.primary.withValues(alpha: 0.35)
            : AppColors.primaryLight,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,
      // Transiciones de página coherentes y suaves en todas las plataformas.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.1,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark ? BorderSide(color: AppColors.border) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        color: AppColors.cardBackground,
      ),
      listTileTheme: ListTileThemeData(iconColor: AppColors.textPrimary),
      // Barra inferior — componentes de la app principal.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: isDark
            ? AppColors.primary.withValues(alpha: 0.25)
            : AppColors.primary.withValues(alpha: 0.12),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? brand
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? brand : AppColors.textSecondary,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        elevation: 3,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          side: BorderSide(color: brand, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: brand,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: brand),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIconColor: brand,
        suffixIconColor: AppColors.textHint,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide(color: AppColors.border),
        backgroundColor: AppColors.inputFill,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: AppTextStyles.bodySmall,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? (isDark ? AppColors.primary.withValues(alpha: 0.3) : AppColors.primary)
                : (isDark ? AppColors.inputFill : AppColors.inputFill),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.textSecondary,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStatePropertyAll(
            AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brand,
        linearTrackColor: AppColors.border,
        circularTrackColor: AppColors.border,
        strokeWidth: 3.0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: AppTextStyles.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textHint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brand;
          return AppColors.border;
        }),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brand;
        return AppColors.textSecondary;
      })),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: AppColors.cardBackground,
        collapsedBackgroundColor: AppColors.cardBackground,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
      visualDensity: VisualDensity.comfortable,
    );
  }
}
