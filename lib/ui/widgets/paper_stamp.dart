import 'package:flutter/material.dart';
import '../../core/models/class_session.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';

class PaperStampBadge extends StatelessWidget {
  final AttendanceStatus status;
  final bool compact;

  const PaperStampBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case AttendanceStatus.present:
        color = AppColors.present;
        text = 'PRESENT';
        icon = Icons.check_circle_outline;
        break;
      case AttendanceStatus.absent:
        color = AppColors.absent;
        text = 'ABSENT';
        icon = Icons.cancel_outlined;
        break;
      case AttendanceStatus.unmarked:
        color = AppColors.unmarked;
        text = 'UNMARKED';
        icon = Icons.help_outline;
        break;
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(160), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// A mini tactile action stamp to toggle Present / Absent / Unmarked directly on class cards
class QuickAttendanceStamps extends StatelessWidget {
  final AttendanceStatus currentStatus;
  final ValueChanged<AttendanceStatus> onStatusChanged;

  const QuickAttendanceStamps({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildChoiceChip(
          text: 'P',
          fullText: 'Present',
          status: AttendanceStatus.present,
          isSelected: currentStatus == AttendanceStatus.present,
          activeColor: AppColors.present,
        ),
        const SizedBox(width: 8),
        _buildChoiceChip(
          text: 'A',
          fullText: 'Absent',
          status: AttendanceStatus.absent,
          isSelected: currentStatus == AttendanceStatus.absent,
          activeColor: AppColors.absent,
        ),
        const SizedBox(width: 8),
        _buildChoiceChip(
          text: '–',
          icon: Icons.remove_rounded,
          fullText: 'Reset',
          status: AttendanceStatus.unmarked,
          isSelected: currentStatus == AttendanceStatus.unmarked,
          activeColor: AppColors.unmarked,
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String text,
    IconData? icon,
    required String fullText,
    required AttendanceStatus status,
    required bool isSelected,
    required Color activeColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: fullText,
        child: InkWell(
          onTap: () {
            HapticService.medium();
            onStatusChanged(status);
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? activeColor : activeColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? activeColor : activeColor.withAlpha(100),
                width: isSelected ? 1.8 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withAlpha(60),
                        offset: const Offset(0, 2),
                        blurRadius: 3,
                      ),
                    ]
                  : null,
            ),
            child: icon != null
                ? Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : activeColor,
                  )
                : Text(
                    text,
                    style: TextStyle(
                      color: isSelected ? Colors.white : activeColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

