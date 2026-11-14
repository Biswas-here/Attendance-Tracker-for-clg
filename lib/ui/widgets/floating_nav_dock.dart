import 'package:flutter/material.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/paper_decorations.dart';

class FloatingNavDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const FloatingNavDock({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dockBg = isDark ? const Color(0xFF262421) : const Color(0xFFFAF7F0);
    final dockBorder = isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong;

    return SafeArea(
      child: RepaintBoundary(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: dockBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: dockBorder, width: 1.5),
            boxShadow: PaperDecorations.dockShadow(isDark: isDark),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
            _buildNavItem(
              context: context,
              index: 0,
              icon: Icons.auto_stories_outlined,
              selectedIcon: Icons.auto_stories,
              label: 'Ledger',
              isDark: isDark,
            ),
            _buildNavItem(
              context: context,
              index: 1,
              icon: Icons.calendar_month_outlined,
              selectedIcon: Icons.calendar_month,
              label: 'Timetable',
              isDark: isDark,
            ),
            _buildNavItem(
              context: context,
              index: 2,
              icon: Icons.library_books_outlined,
              selectedIcon: Icons.library_books,
              label: 'Subjects',
              isDark: isDark,
            ),
            _buildNavItem(
              context: context,
              index: 3,
              icon: Icons.insert_chart_outlined_rounded,
              selectedIcon: Icons.insert_chart_rounded,
              label: 'Analytics',
              isDark: isDark,
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = AppColors.craftTeal;
    final inactiveColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTapDown: (_) => HapticService.light(),
      onTap: () {
        HapticService.medium();
        onIndexChanged(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withAlpha(isDark ? 55 : 28)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: isSelected
              ? Border.all(color: activeColor.withAlpha(130), width: 1.2)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(isDark ? 45 : 25),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
