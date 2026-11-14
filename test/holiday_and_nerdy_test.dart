import 'package:attendance_tracker/core/models/class_session.dart';
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

    test('Declared holiday dates correctly identify custom holiday set', () {
      final settings = UserSettings(
        customHolidays: '2026-11-20,2026-11-21',
      );
      expect(settings.customHolidaysSet.contains('2026-11-20'), true);
      expect(settings.customHolidaysSet.contains('2026-11-21'), true);
      expect(HolidayUtils.isHoliday(DateTime(2026, 11, 20), settings), true);
      expect(HolidayUtils.isHoliday(DateTime(2026, 11, 23), settings), false);
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

  group('Semester Range & Notification Safeguard Tests', () {
    test('isSemesterEnded returns true after semester end date', () {
      final pastEndSettings = UserSettings(
        semesterStartDate: '2026-08-01',
        semesterEndDate: '2026-11-01',
      );
      expect(pastEndSettings.isSemesterEnded, true);
    });

    test('isSemesterEnded returns false while semester is ongoing', () {
      final ongoingSettings = UserSettings(
        semesterStartDate: '2026-08-01',
        semesterEndDate: '2026-12-31',
      );
      expect(ongoingSettings.isSemesterEnded, false);
    });

    test('isDateInSemester correctly identifies in/out of range dates', () {
      final settings = UserSettings(
        semesterStartDate: '2026-08-01',
        semesterEndDate: '2026-12-15',
      );

      final inDate = DateTime(2026, 10, 10);
      final outDate = DateTime(2026, 12, 20);

      expect(settings.isDateInSemester(inDate), true);
      expect(settings.isDateInSemester(outDate), false);
    });
  });

  group('Exam Session Model & Persistence Tests', () {
    test('ClassSession identifies exam session via isExam flag or room label', () {
      final exam1 = ClassSession(
        id: 'exam_1',
        subjectId: 'sub_math',
        date: '2026-11-17',
        startTime: '10:00',
        endTime: '13:00',
        room: 'Hall 201',
        isExam: true,
      );
      expect(exam1.isExam, true);
      expect(exam1.isExamSession, true);

      final exam2 = ClassSession(
        id: 'exam_2',
        subjectId: 'sub_cs',
        date: '2026-11-19',
        startTime: '09:30',
        endTime: '12:30',
        room: 'Lab 1 • Lab Exam',
      );
      expect(exam2.isExamSession, true);

      final regularClass = ClassSession(
        id: 'class_1',
        subjectId: 'sub_math',
        date: '2026-11-16',
        startTime: '10:00',
        endTime: '11:00',
        room: 'Room 101',
      );
      expect(regularClass.isExam, false);
      expect(regularClass.isExamSession, false);
    });

    test('ClassSession serialization preserves is_exam flag', () {
      final session = ClassSession(
        id: 'sess_exam_test',
        subjectId: 'sub_physics',
        date: '2026-11-21',
        startTime: '10:00',
        endTime: '13:00',
        room: 'Exam Hall A',
        isExam: true,
      );

      final map = session.toMap();
      expect(map['is_exam'], 1);

      final restored = ClassSession.fromMap(map);
      expect(restored.id, 'sess_exam_test');
      expect(restored.isExam, true);
      expect(restored.isExamSession, true);
    });
  });
}

