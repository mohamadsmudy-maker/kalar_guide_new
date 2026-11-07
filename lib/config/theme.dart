// lib/config/theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 🎨 ڕووکاری گشتی ئەپ — Ultra Pro Max
class AppTheme {
  AppTheme._();

  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.secondary;
  static const Color backgroundColor = AppColors.background;
  static const Color textColor = AppColors.textPrimary;

  static const String defaultFontFamily = 'Rabar';
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusXLarge = 28.0;

  static const TextTheme _baseTextTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.3),
    displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.3),
    displaySmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
    headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3),
    headlineMedium: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.35),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.4),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4),
    bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.5),
    bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.5),
    bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
  );

  static TextTheme baseTextTheme() => _baseTextTheme;

  static TextTheme lightTextTheme() => _baseTextTheme.apply(
    fontFamily: defaultFontFamily,
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  static TextTheme darkTextTheme() => _baseTextTheme.apply(
    fontFamily: defaultFontFamily,
    bodyColor: AppColors.darkTextPrimary,
    displayColor: AppColors.darkTextPrimary,
  );

  static TextTheme _decorateSecondary(TextTheme base, {required bool dark}) {
    return base.copyWith(
      bodyMedium: base.bodyMedium?.copyWith(
        color: dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: dark ? AppColors.darkTextTertiary : AppColors.textTertiary,
      ),
      labelMedium: base.labelMedium?.copyWith(
        color: dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        color: dark ? AppColors.darkTextTertiary : AppColors.textTertiary,
      ),
    );
  }

  static ThemeData lightTheme({TextTheme? textTheme}) {
    final tt = _decorateSecondary(
      textTheme ?? lightTextTheme(),
      dark: false,
    );
    return _buildTheme(
      brightness: Brightness.light,
      textTheme: tt,
      scaffold: AppColors.background,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      card: AppColors.surface,
      border: AppColors.border,
      hint: AppColors.textTertiary,
      appBarFg: AppColors.textPrimary,
      navBg: AppColors.surface,
      navSelected: primaryColor,
      navUnselected: AppColors.textTertiary,
      dialogBg: AppColors.surface,
      sheetBg: AppColors.surface,
      snackBg: AppColors.textPrimary,
      divider: AppColors.divider,
    );
  }

  static ThemeData darkTheme({TextTheme? textTheme}) {
    final tt = _decorateSecondary(
      textTheme ?? darkTextTheme(),
      dark: true,
    );
    return _buildTheme(
      brightness: Brightness.dark,
      textTheme: tt,
      scaffold: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      onSurface: Colors.white,
      card: AppColors.darkCard,
      border: AppColors.darkBorder,
      hint: AppColors.darkTextTertiary,
      appBarFg: Colors.white,
      navBg: AppColors.darkSurface,
      navSelected: primaryColor,
      navUnselected: AppColors.darkTextTertiary,
      dialogBg: AppColors.darkCard,
      sheetBg: AppColors.darkCard,
      snackBg: AppColors.darkSurface,
      divider: AppColors.darkBorder,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required TextTheme textTheme,
    required Color scaffold,
    required Color surface,
    required Color onSurface,
    required Color card,
    required Color border,
    required Color hint,
    required Color appBarFg,
    required Color navBg,
    required Color navSelected,
    required Color navUnselected,
    required Color dialogBg,
    required Color sheetBg,
    required Color snackBg,
    required Color divider,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffold,
      fontFamily: defaultFontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surface,
        error: AppColors.red,
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: primaryColor.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: defaultFontFamily,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: defaultFontFamily,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        elevation: 0,
        margin: const EdgeInsets.all(8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: appBarFg,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: onSurface,
          fontFamily: defaultFontFamily,
        ),
        iconTheme: IconThemeData(color: appBarFg),
      ),
      iconTheme: IconThemeData(
        color: brightness == Brightness.dark ? Colors.white : primaryColor,
        size: 24,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
        hintStyle: TextStyle(
          color: hint,
          fontSize: 14,
          fontFamily: defaultFontFamily,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brightness == Brightness.dark
            ? AppColors.primarySoft.withValues(alpha: 0.15)
            : AppColors.primarySoft,
        selectedColor: primaryColor,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          fontFamily: defaultFontFamily,
          color: onSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBg,
        selectedItemColor: navSelected,
        unselectedItemColor: navUnselected,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          fontFamily: defaultFontFamily,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          fontFamily: defaultFontFamily,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        indicatorColor: primaryColor.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: defaultFontFamily,
            color: onSurface,
          ),
        ),
        iconTheme: WidgetStateProperty.all(
          IconThemeData(color: onSurface),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBg,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: defaultFontFamily,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXLarge),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: surface,
          fontSize: 12,
          fontFamily: defaultFontFamily,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          primaryColor.withValues(alpha: 0.4),
        ),
        radius: const Radius.circular(8),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeColors(
          primary: primaryColor,
          secondary: secondaryColor,
          success: AppColors.success,
          warning: AppColors.warning,
          info: AppColors.info,
          danger: AppColors.danger,
        ),
      ],
    );
  }
}

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color primary;
  final Color secondary;
  final Color success;
  final Color warning;
  final Color info;
  final Color danger;

  const AppThemeColors({
    required this.primary,
    required this.secondary,
    required this.success,
    required this.warning,
    required this.info,
    required this.danger,
  });

  @override
  AppThemeColors copyWith({
    Color? primary,
    Color? secondary,
    Color? success,
    Color? warning,
    Color? info,
    Color? danger,
  }) {
    return AppThemeColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}