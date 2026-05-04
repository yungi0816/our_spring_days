import 'package:flutter/material.dart';

class AppTheme {
  // 봄 느낌의 파스텔 컬러 팔레트
  static const Color primaryPink = Color(0xFFFFD1DC); // 연분홍
  static const Color accentCoral = Color(0xFFFFB7A1); // 코랄
  static const Color springGreen = Color(0xFFE2F0CB); // 연두색
  static const Color backgroundWhite = Color(0xFFFFF9F9); // 아주 연한 핑크빛 화이트
  static const Color textDark = Color(0xFF4A4A4A); // 부드러운 다크 그레이

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPink,
        primary: primaryPink,
        secondary: accentCoral,
        tertiary: springGreen,
        surface: backgroundWhite,
      ),
      scaffoldBackgroundColor: backgroundWhite,

      // 카드 테마: 둥근 모서리 적용
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),

      // 앱바 테마
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textDark),
      ),

      // 하단 네비게이션 바 테마
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: accentCoral,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),

      // 텍스트 테마 (기본 폰트는 나중에 설정)
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textDark, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textDark),
        bodyMedium: TextStyle(color: textDark),
      ),

      // 버튼 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: textDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
