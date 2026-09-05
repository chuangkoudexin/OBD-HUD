import 'package:flutter/material.dart';

/// OBD HUD 全局配色 / 深色 HUD 主题
class HudColors {
  HudColors._();

  static const Color bg = Color(0xFF070B12);
  static const Color bgPanel = Color(0xFF111925);
  static const Color bgPanelAlt = Color(0xFF0C1320);
  static const Color stroke = Color(0xFF24324A);
  static const Color strokeBright = Color(0xFF3B527A);

  static const Color accent = Color(0xFF00E5FF);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentRed = Color(0xFFFF3B30);
  static const Color accentYellow = Color(0xFFFFD740);
  static const Color accentPurple = Color(0xFFB388FF);
  static const Color accentBlue = Color(0xFF448AFF);
  static const Color accentTeal = Color(0xFF26C6DA);

  static const Color textPrimary = Color(0xFFF2F5FA);
  static const Color textSecondary = Color(0xFF93A4BE);

  static const Color ok = Color(0xFF00E676);
  static const Color warn = Color(0xFFFFB300);
  static const Color danger = Color(0xFFFF3B30);
}

class HudTheme {
  HudTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: HudColors.accent,
      secondary: HudColors.accentGreen,
      surface: HudColors.bgPanel,
      error: HudColors.danger,
      onPrimary: Color(0xFF00131A),
      onSecondary: Color(0xFF00130A),
      onSurface: HudColors.textPrimary,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: HudColors.bg,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: HudColors.textPrimary,
        displayColor: HudColors.textPrimary,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: HudColors.bgPanelAlt,
        indicatorColor: HudColors.accent.withValues(alpha: 0.16),
        selectedIconTheme: const IconThemeData(color: HudColors.accent),
        unselectedIconTheme: const IconThemeData(color: HudColors.textSecondary),
        selectedLabelTextStyle: const TextStyle(
          color: HudColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: HudColors.textSecondary,
          fontSize: 12,
        ),
      ),
      dividerTheme: const DividerThemeData(color: HudColors.stroke),
      dialogTheme: DialogThemeData(
        backgroundColor: HudColors.bgPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HudColors.bgPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HudColors.bgPanel,
        contentTextStyle: const TextStyle(color: HudColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HudColors.bgPanelAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HudColors.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HudColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HudColors.accent),
        ),
        hintStyle: const TextStyle(color: HudColors.textSecondary),
      ),
    );
  }
}
