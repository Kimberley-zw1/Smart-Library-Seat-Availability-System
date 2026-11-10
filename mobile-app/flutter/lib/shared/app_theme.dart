import 'package:flutter/material.dart';

/// Named colors that change between light and dark mode.
/// In a screen, write context.colors.textPrimary, context.colors.surface, etc.
class AppColors extends ThemeExtension<AppColors> {
  final Color background; // page background
  final Color surface; // cards, sheets, bars sitting on the background
  final Color card; // slightly raised / tinted panels
  final Color border; // card borders, dividers
  final Color textPrimary; // main text
  final Color textSecondary; // subtitles, descriptions
  final Color textMuted; // timestamps, hints, inactive icons
  final Color softPink; // light pink icon backgrounds
  final Color neutralFill; // neutral grey circles / avatars

  const AppColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.softPink,
    required this.neutralFill,
  });

  static const light = AppColors(
    background: Colors.white,
    surface: Colors.white,
    card: Color(0xFFF8F9FA),
    border: Color(0xFFEEEEEE),
    textPrimary: Colors.black87,
    textSecondary: Color(0xFF6C757D),
    textMuted: Color(0xFF94A3B8),
    softPink: Color(0xFFFFF0F3),
    neutralFill: Color(0xFFE9ECEF),
  );

  static const dark = AppColors(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    card: Color(0xFF242426),
    border: Color(0xFF3A3A3C),
    textPrimary: Color(0xFFEDEDED),
    textSecondary: Color(0xFFA7ADBA),
    textMuted: Color(0xFF7C8594),
    softPink: Color(0xFF3A1F25),
    neutralFill: Color(0xFF2C2C2E),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? softPink,
    Color? neutralFill,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      softPink: softPink ?? this.softPink,
      neutralFill: neutralFill ?? this.neutralFill,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      softPink: Color.lerp(softPink, other.softPink, t)!,
      neutralFill: Color.lerp(neutralFill, other.neutralFill, t)!,
    );
  }
}

/// Shortcuts so any screen can write context.colors / context.isDark
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  AppTheme._();

  static const Color _red = Color(0xFFC01A32);

  static ThemeData _build(Brightness brightness, AppColors c) {
    return ThemeData(
      useMaterial3: true,
      // Same seed the app used before, so light mode looks the same
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueAccent,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: c.background,
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: _red,
        unselectedItemColor: c.textMuted,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: c.border),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected) ? _red : null,
        ),
      ),
    );
  }

  static final ThemeData light = _build(Brightness.light, AppColors.light);
  static final ThemeData dark = _build(Brightness.dark, AppColors.dark);
}
