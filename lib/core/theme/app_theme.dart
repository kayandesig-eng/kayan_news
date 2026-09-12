import 'package:flutter/material.dart';

/// الهوية البصرية الموحدة لتطبيق KAYAN NEWS.
///
/// تستخدم هذه الطبقة لتوحيد ألوان ومكونات الواجهة
/// وجعل تطوير التصميم مستقبلاً أسهل وأكثر اتساقًا.
class AppTheme {
  AppTheme._();

  // ألوان KAYAN NEWS الأساسية
  static const Color background = Color(0xFF081017);
  static const Color surface = Color(0xFF0B151C);
  static const Color surfaceElevated = Color(0xFF121D24);

  // اللون الرئيسي للهوية
  static const Color primary = Color(0xFF35D5C4);
  static const Color primaryDark = Color(0xFF183D3A);

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      secondary: primary,
      surface: surface,
    );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,

      scaffoldBackgroundColor: background,

      colorScheme: colorScheme,

      fontFamily: 'Arial',

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),

      cardTheme: const CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryDark,
      ),

      chipTheme: const ChipThemeData(
        backgroundColor: surfaceElevated,
        selectedColor: primary,
        side: BorderSide.none,
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
      ),
    );
  }
}
