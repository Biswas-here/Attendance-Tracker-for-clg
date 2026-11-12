import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/core/models/class_session.dart';
import 'package:attendance_tracker/core/models/subject.dart';
import 'package:attendance_tracker/core/utils/attendance_calculator.dart';

void main() {
  group('AttendanceCalculator Tests', () {
    test('Calculates individual subject attendance correctly', () {
      final sessions = [
        ClassSession(
          id: '1',
          subjectId: 'sub1',
          date: '2026-11-08',
          startTime: '09:00',
          endTime: '10:00',
          status: AttendanceStatus.present,
        ),
        ClassSession(
          id: '2',
          subjectId: 'sub1',
          date: '2026-11-09',
          startTime: '09:00',
          endTime: '10:00',
          status: AttendanceStatus.present,
        ),
        ClassSession(
          id: '3',
          subjectId: 'sub1',
          date: '2026-11-10',
          startTime: '09:00',
          endTime: '10:00',
          status: AttendanceStatus.absent,
        ),
        ClassSession(
          id: '4',
          subjectId: 'sub1',
          date: '2026-11-11',
          startTime: '09:00',
          endTime: '10:00',
          status: AttendanceStatus.unmarked,
        ),
      ];

      final stats = AttendanceCalculator.calculateSubjectStats(sessions);

      expect(stats.presentCount, 2);
      expect(stats.absentCount, 1);
      expect(stats.unmarkedCount, 1);
      expect(stats.totalMarked, 3);
      // 2 / 3 * 100 = 66.7%
      expect(stats.percentage, 66.7);
      expect(stats.meetsTarget(75.0), isFalse);
    });

    test('Zero marked classes returns null percentage (displayed as --)', () {
      final sessions = [
        ClassSession(
          id: '1',
          subjectId: 'sub1',
          date: '2026-11-08',
          startTime: '09:00',
          endTime: '10:00',
          status: AttendanceStatus.unmarked,
        ),
      ];

      final stats = AttendanceCalculator.calculateSubjectStats(sessions);
      expect(stats.percentage, isNull);
      expect(stats.meetsTarget(75.0), isFalse);
    });

    test('Calculates consecutive classes needed to reach target', () {
      // 2 present, 2 absent -> 50%
      // To reach 75%: (2 + x) / (4 + x) >= 0.75
      // 2 + x >= 3 + 0.75x -> 0.25x >= 1 -> x >= 4 classes
      final sessions = [
        ClassSession(
          id: '1',
          subjectId: 'sub1',
          date: '2026-11-01',
          startTime: '09:00',
          endTime: '10:00',
          status: AttendanceStatus.present,
        ),
        ClassSession(
          id: '2',
          subjectId: 'sub1',
          date: '2026-11-02',
          startTime: '09:00',
          endTime: '10:00',
          status: AttendanceStatus.present,
        ),
        ClassSession(
          id: '3',
          subjectId: 'sub1',
          date: '2026-11-03',
          startTime: '09:00',
          endTime: '10:00',
          status: AttendanceStatus.absent,
        ),
        ClassSession(
          id: '4',
          subjectId: 'sub1',
          date: '2026-11-04',
          startTime: '09:00',
          endTime: '10:00',
          status: AttendanceStatus.absent,
        ),
      ];

      final stats = AttendanceCalculator.calculateSubjectStats(sessions);
      expect(stats.classesNeededForTarget(75.0), 4);
    });

    test('Calculates classes that can safely be missed', () {
      // 9 present, 1 absent -> 90%
      // Target is 75%: 9 / (10 + y) >= 0.75 -> 9 >= 7.5 + 0.75y -> 1.5 >= 0.75y -> y <= 2 classes
      final sessions = List.generate(
        9,
        (i) => ClassSession(
          id: 'p$i',
          subjectId: 'sub1',
          date: '2026-11-01',
          startTime: '09:00',
          endTime: '10:00',
          status: AttendanceStatus.present,
        ),
      )..add(
          ClassSession(
            id: 'a1',
            subjectId: 'sub1',
            date: '2026-11-02',
            startTime: '09:00',
            endTime: '10:00',
            status: AttendanceStatus.absent,
          ),
        );

      final stats = AttendanceCalculator.calculateSubjectStats(sessions);
      expect(stats.classesCanMiss(75.0), 2);
    });

    test('Overall attendance sums across multiple subjects without averaging percentages', () {
      // Sub 1: 1 present, 0 absent (100%)
      // Sub 2: 9 present, 10 absent (47.4%)
      // Total: 10 present, 10 absent = 50.0% (NOT (100 + 47.4)/2 = 73.7%)
      final sessions = [
        ClassSession(
          id: 's1_1',
          subjectId: 'sub1',
          date: '2026-11-01',
          startTime: '09:00',
          endTime: '10:00',
          status: AttendanceStatus.present,
        ),
        ...List.generate(
          9,
          (i) => ClassSession(
            id: 's2_p$i',
            subjectId: 'sub2',
            date: '2026-11-02',
            startTime: '10:00',
            endTime: '11:00',
            status: AttendanceStatus.present,
          ),
        ),
        ...List.generate(
          10,
          (i) => ClassSession(
            id: 's2_a$i',
            subjectId: 'sub2',
            date: '2026-11-03',
            startTime: '10:00',
            endTime: '11:00',
            status: AttendanceStatus.absent,
          ),
        ),
      ];

      final overall = AttendanceCalculator.calculateOverallStats(sessions);
      expect(overall.totalPresent, 10);
      expect(overall.totalAbsent, 10);
      expect(overall.percentage, 50.0);
    });
  });

  group('Subject Model Tests', () {
    test('Subject serialization round trip', () {
      final sub = Subject(
        id: 'uuid-123',
        name: 'Calculus',
        code: 'MATH101',
        teacher: 'Dr. Euler',
        targetPercentage: 80.0,
        colorValue: 0xFF3F7E7D,
      );

      final map = sub.toMap();
      final restored = Subject.fromMap(map);

      expect(restored.id, 'uuid-123');
      expect(restored.name, 'Calculus');
      expect(restored.code, 'MATH101');
      expect(restored.teacher, 'Dr. Euler');
      expect(restored.targetPercentage, 80.0);
      expect(restored.colorValue, 0xFF3F7E7D);
    });
  });
}

