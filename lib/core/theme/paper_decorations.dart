import 'package:flutter/material.dart';
import 'app_colors.dart';

class PaperDecorations {
  static BoxDecoration? _defaultLightCard;
  static BoxDecoration? _defaultDarkCard;

  static const _lightDockShadow = [
    BoxShadow(
      color: Color(0x3C000000), // withAlpha(60)
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: Color(0x23000000), // withAlpha(35)
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  static const _darkDockShadow = [
    BoxShadow(
      color: Color(0xAA000000), // withAlpha(170)
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: Color(0x5A000000), // withAlpha(90)
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  // ---------------------------------------------------------------------------
  // CARD DECORATIONS - Depth effect uses crisp black drop shadows
  // ---------------------------------------------------------------------------

  /// Standard paper card — crisp border + layered physical black drop shadow
  static BoxDecoration paperCardDecoration({
    required BuildContext context,
    Color? color,
    Color? borderColor,
    double borderWidth = 1.5,
    double borderRadius = 16.0,
    bool raised = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Cache the most commonly used default paper card decorations
    if (color == null && borderColor == null && borderWidth == 1.5 && borderRadius == 16.0 && raised) {
      if (isDark) {
        return _defaultDarkCard ??= _buildPaperCardDecoration(isDark, null, null, borderWidth, borderRadius, raised);
      } else {
        return _defaultLightCard ??= _buildPaperCardDecoration(isDark, null, null, borderWidth, borderRadius, raised);
      }
    }

    return _buildPaperCardDecoration(isDark, color, borderColor, borderWidth, borderRadius, raised);
  }

  static BoxDecoration _buildPaperCardDecoration(
    bool isDark,
    Color? color,
    Color? borderColor,
    double borderWidth,
    double borderRadius,
    bool raised,
  ) {
    final cardBg = color ?? (isDark ? AppColors.darkCard : AppColors.lightCard);
    final border = borderColor ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border, width: borderWidth),
      boxShadow: raised
          ? [
              // Black ambient soft shadow
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 90 : 35),
                offset: const Offset(0, 3),
                blurRadius: 8,
                spreadRadius: 0,
              ),
              // Black directional key shadow — physical paper depth
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 110 : 45),
                offset: const Offset(0, 5),
                blurRadius: 14,
                spreadRadius: -2,
              ),
              // Crisp bottom black edge line
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 80 : 25),
                offset: const Offset(0, 1),
                blurRadius: 1,
                spreadRadius: 0,
              ),
            ]
          : null,
    );
  }

  /// Elevated card — pronounced black depth for hero sections
  static BoxDecoration elevatedCardDecoration({
    required BuildContext context,
    Color? color,
    Color? borderColor,
    double borderRadius = 20.0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = color ?? (isDark ? AppColors.darkCardElevated : AppColors.lightCardElevated);
    final border = borderColor ?? (isDark ? AppColors.darkBorderStrong : AppColors.lightBorder);

    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border, width: 1.5),
      boxShadow: [
        // Deep black ambient
        BoxShadow(
          color: Colors.black.withAlpha(isDark ? 120 : 50),
          offset: const Offset(0, 6),
          blurRadius: 20,
          spreadRadius: 0,
        ),
        // Strong black directional
        BoxShadow(
          color: Colors.black.withAlpha(isDark ? 140 : 65),
          offset: const Offset(0, 10),
          blurRadius: 24,
          spreadRadius: -3,
        ),
        // Sharp black physical edge
        BoxShadow(
          color: Colors.black.withAlpha(isDark ? 100 : 40),
          offset: const Offset(0, 2),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BUTTON DECORATIONS - Depth effect with black physical shadow
  // ---------------------------------------------------------------------------

  /// Tactile raised button — paper-like press effect using black depth
  static BoxDecoration tactileButtonDecoration({
    required Color color,
    Color? borderColor,
    double borderRadius = 12.0,
    bool isPressed = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? color.withAlpha(200),
        width: 1.5,
      ),
      boxShadow: isPressed
          ? [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                offset: const Offset(0, 1),
                blurRadius: 1,
              ),
            ]
          : [
              // Black physical drop
              BoxShadow(
                color: Colors.black.withAlpha(65),
                offset: const Offset(0, 3),
                blurRadius: 0,
                spreadRadius: 0,
              ),
              // Soft black ambient
              BoxShadow(
                color: Colors.black.withAlpha(40),
                offset: const Offset(0, 5),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
    );
  }

  /// Colored attendance button with black depth shadow and colored glow
  static BoxDecoration attendanceButtonDecoration({
    required Color color,
    bool isPressed = false,
    double borderRadius = 16.0,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: color.withAlpha(200),
        width: 1.5,
      ),
      boxShadow: isPressed
          ? [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ]
          : [
              // Colored glow
              BoxShadow(
                color: color.withAlpha(80),
                offset: const Offset(0, 6),
                blurRadius: 18,
                spreadRadius: 0,
              ),
              // Sharp physical black edge
              BoxShadow(
                color: Colors.black.withAlpha(75),
                offset: const Offset(0, 4),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
    );
  }

  // ---------------------------------------------------------------------------
  // STAMP / BADGE
  // ---------------------------------------------------------------------------

  /// Stamp badge decoration (inked paper feel)
  static BoxDecoration stampDecoration({
    required Color color,
    bool filled = false,
    double borderRadius = 8.0,
  }) {
    return BoxDecoration(
      color: filled ? color.withAlpha(35) : Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: color,
        width: 1.5,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FLOATING DOCK - Pure black depth shadow
  // ---------------------------------------------------------------------------

  /// Bottom nav dock shadow using black for depth
  static List<BoxShadow> dockShadow({required bool isDark}) {
    return isDark ? _darkDockShadow : _lightDockShadow;
  }
}

// ---------------------------------------------------------------------------
// WashiTape — decorative scrapbook header strip
// ---------------------------------------------------------------------------
class WashiTape extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double rotationAngle;

  const WashiTape({
    super.key,
    this.width = 70,
    this.height = 14,
    this.color = AppColors.kraftGold,
    this.rotationAngle = -0.04,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationAngle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color.withAlpha(190),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              offset: const Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}
