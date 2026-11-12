import 'package:attendance_tracker/core/models/user_settings.dart';
import 'package:attendance_tracker/core/utils/attendance_calculator.dart';
import 'package:attendance_tracker/core/utils/holiday_utils.dart';
import 'package:attendance_tracker/core/utils/nerdy_icons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HolidayUtils Tests', () {
    test('Identifies Sundays as holidays', () {
      final settings = UserSettings(saturdayHolidayPattern: 'none');
      final sunday = DateTime(2026, 11, 8); // Sunday
      expect(HolidayUtils.isHoliday(sunday, settings), true);
      expect(HolidayUtils.getHolidayReason(sunday, settings), 'Sunday Off');
    });

    test('Handles 2nd and 4th Saturday off pattern', () {
      final settings = UserSettings(saturdayHolidayPattern: 'second_fourth');

      // November 2026:
      // Nov 7 = 1st Saturday -> Working
      // Nov 14 = 2nd Saturday -> Off
      // Nov 21 = 3rd Saturday -> Working
      // Nov 28 = 4th Saturday -> Off
      final sat1 = DateTime(2026, 11, 7);
      final sat2 = DateTime(2026, 11, 14);
      final sat3 = DateTime(2026, 11, 21);
      final sat4 = DateTime(2026, 11, 28);

      expect(HolidayUtils.isHoliday(sat1, settings), false);
      expect(HolidayUtils.isHoliday(sat2, settings), true);
      expect(HolidayUtils.getHolidayReason(sat2, settings), '2nd Saturday Off');

      expect(HolidayUtils.isHoliday(sat3, settings), false);
      expect(HolidayUtils.isHoliday(sat4, settings), true);
      expect(HolidayUtils.getHolidayReason(sat4, settings), '4th Saturday Off');
    });

    test('Handles 1st and 3rd Saturday off pattern', () {
      final settings = UserSettings(saturdayHolidayPattern: 'first_third');

      final sat1 = DateTime(2026, 11, 7);
      final sat2 = DateTime(2026, 11, 14);

      expect(HolidayUtils.isHoliday(sat1, settings), true);
      expect(HolidayUtils.getHolidayReason(sat1, settings), '1st Saturday Off');
      expect(HolidayUtils.isHoliday(sat2, settings), false);
    });

    test('Handles custom declared holiday dates', () {
      final settings = UserSettings(
        saturdayHolidayPattern: 'none',
        customHolidays: '2026-11-12,2026-12-25',
      );

      final holidayDate = DateTime(2026, 11, 12);
      final regularDate = DateTime(2026, 11, 13);

      expect(HolidayUtils.isHoliday(holidayDate, settings), true);
      expect(HolidayUtils.getHolidayReason(holidayDate, settings), 'Declared Holiday');
      expect(HolidayUtils.isHoliday(regularDate, settings), false);
    });
  });

  group('NerdyIcons Tests', () {
    test('Returns deterministic icons for subject names', () {
      final icon1 = NerdyIcons.getIcon('Database Management');
      final icon2 = NerdyIcons.getIcon('Database Management');
      expect(icon1, equals(icon2));

      final icon3 = NerdyIcons.getIcon('Artificial Intelligence');
      expect(NerdyIcons.icons.contains(icon3), true);
    });
  });

  group('Overall Attendance Stats Calculations', () {
    test('Calculates classes needed and safe miss for overall stats', () {
      // 7 present out of 10 = 70%, target = 75%
      final stats = OverallAttendanceStats(
        totalPresent: 7,
        totalAbsent: 3,
        totalUnmarked: 0,
        percentage: 70.0,
      );

      // (7 + 2) / (10 + 2) = 9/12 = 75% -> needs 2
      final needed = AttendanceCalculator.classesNeededToReachTarget(stats, 75.0);
      expect(needed, 2);

      // 8 present out of 10 = 80%, target = 75%
      final statsAbove = OverallAttendanceStats(
        totalPresent: 8,
        totalAbsent: 2,
        totalUnmarked: 0,
        percentage: 80.0,
      );
      // 8 / (10 + 0) = 80%, 8 / 11 = 72.7% -> can miss 0
      final canMiss = AttendanceCalculator.classesCanSafelyMiss(statsAbove, 75.0);
      expect(canMiss, 0);

      // 9 present out of 10 = 90%, target = 75%
      // 9 / 12 = 75% -> can miss 2
      final statsHigh = OverallAttendanceStats(
        totalPresent: 9,
        totalAbsent: 1,
        totalUnmarked: 0,
        percentage: 90.0,
      );
      final canMiss2 = AttendanceCalculator.classesCanSafelyMiss(statsHigh, 75.0);
      expect(canMiss2, 2);
    });
  });
}

