import 'package:flutter/material.dart';

/// 앱 전역에서 사용하는 감성 카페 & 뉴트럴 미니멀 컬러 팔레트
class AppColors {
  AppColors._();

  // Primary 감성 카페/에스프레소 톤
  static const Color primary = Color(0xFF2C2523); // 웜 딥 에스프레소
  static const Color primaryLight = Color(0xFF4A3B32); // 모카 브라운
  static const Color primaryDark = Color(0xFF1A1615); // 다크 에스프레소
  static const Color primaryContainer = Color(0xFFF2ECE6); // 연한 베이지 컨테이너

  // Accent / 보조 포인트
  static const Color accent = Color(0xFF8D7B68); // 웜 토프 / 라떼
  static const Color accentLight = Color(0xFFC4B5A5);
  static const Color warmBeige = Color(0xFFF5EFEB);
  static const Color warmSand = Color(0xFFE8DFD8);

  // 배경 및 표면 컬러
  static const Color backgroundLight = Color(0xFFF8F9FA); // 웜 그레이시 소프트 오프화이트
  static const Color surfaceLight = Colors.white;
  static const Color backgroundDark = Color(0xFF141414);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // 테두리 & 디바이더 (은은한 1px 보더)
  static const Color borderLight = Color(0x0F000000); // 6% black
  static const Color borderSubtle = Color(0x14000000); // 8% black
  static const Color borderDark = Color(0x1FFFFFFF); // 12% white

  // 텍스트 컬러
  static const Color textPrimaryLight = Color(0xFF1C1C1E);
  static const Color textSecondaryLight = Color(0xFF6E6D6B);
  static const Color textTertiaryLight = Color(0xFF9E9E9C);

  static const Color textPrimaryDark = Color(0xFFF2F2F7);
  static const Color textSecondaryDark = Color(0xFF98989D);
}
