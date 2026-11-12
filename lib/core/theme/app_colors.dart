import 'package:flutter/material.dart';

class AppColors {
  // Light Palette - Warm Handmade Paper Scrapbook
  static const Color lightBg = Color(0xFFF7F4EC);
  static const Color lightSurface = Color(0xFFFCFAF5);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardElevated = Color(0xFFFEFCF8);
  static const Color lightBorder = Color(0xFFE2DDD2);
  static const Color lightBorderStrong = Color(0xFFC7BFB0);
  static const Color lightTextPrimary = Color(0xFF2B2824);
  static const Color lightTextSecondary = Color(0xFF746E66);
  static const Color lightTextTertiary = Color(0xFFA59E94);

  // Dark Palette - Deep Slate Notebook
  static const Color darkBg = Color(0xFF161514);
  static const Color darkSurface = Color(0xFF201E1C);
  static const Color darkCard = Color(0xFF282522);
  static const Color darkCardElevated = Color(0xFF302D29);
  static const Color darkBorder = Color(0xFF3E3A34);
  static const Color darkBorderStrong = Color(0xFF555047);
  static const Color darkTextPrimary = Color(0xFFF0EBE1);
  static const Color darkTextSecondary = Color(0xFFA8A196);
  static const Color darkTextTertiary = Color(0xFF797369);

  // Shadow Tokens
  static const Color shadowAmbientLight = Color(0x0F3E3020);  // very subtle ambient
  static const Color shadowKeyLight = Color(0x1A3E3020);       // directional key
  static const Color shadowDeepLight = Color(0x283E3020);      // deeper shadow
  static const Color shadowAmbientDark = Color(0x50000000);
  static const Color shadowKeyDark = Color(0x70000000);

  // Attendance Status Colors (Physical Stamp / Ink feel)
  static const Color present = Color(0xFF2E7D32); // Deep botanical green
  static const Color presentLight = Color(0xFFE8F5E9);
  static const Color presentBorder = Color(0xFF81C784);
  static const Color presentShadow = Color(0x402E7D32);    // green glow shadow
  static const Color presentShadowDeep = Color(0x602E7D32);

  static const Color absent = Color(0xFFC62828); // Rich brick red
  static const Color absentLight = Color(0xFFFFEBEE);
  static const Color absentBorder = Color(0xFFE57373);
  static const Color absentShadow = Color(0x40C62828);     // red glow shadow
  static const Color absentShadowDeep = Color(0x60C62828);

  static const Color unmarked = Color(0xFF757575); // Slate / Pencil lead
  static const Color unmarkedLight = Color(0xFFEEEEEE);
  static const Color unmarkedBorder = Color(0xFFBDBDBD);

  // Decorative Scrapbook Accents (Washi tape, paper clips, stamp ink)
  static const Color kraftGold = Color(0xFFD49A3D);
  static const Color kraftBrown = Color(0xFF8D6E63);
  static const Color craftTeal = Color(0xFF3F7E7D);
  static const Color craftTealLight = Color(0xFFE0F0F0);
  static const Color craftPlum = Color(0xFF7B4B74);
  static const Color craftIndigo = Color(0xFF3F51B5);
  static const Color craftOrange = Color(0xFFE65100);

  // Preset colors for Subject badges
  static const List<Color> subjectTagColors = [
    Color(0xFF3F7E7D), // Craft Teal
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFD49A3D), // Kraft Gold
    Color(0xFF7B4B74), // Craft Plum
    Color(0xFF558B2F), // Olive Green
    Color(0xFFAD1457), // Rosewood
    Color(0xFF455A64), // Slate
    Color(0xFFE65100), // Terracotta
  ];
}
