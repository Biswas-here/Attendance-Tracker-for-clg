import 'dart:math';
import '../models/class_session.dart';

class SubjectAttendanceStats {
  final int presentCount;
  final int absentCount;
  final int unmarkedCount;
  final double? percentage; // null if presentCount + absentCount == 0

  SubjectAttendanceStats({
    required this.presentCount,
    required this.absentCount,
    required this.unmarkedCount,
    required this.percentage,
  });

  int get totalMarked => presentCount + absentCount;
  int get totalClasses => presentCount + absentCount + unmarkedCount;

  bool meetsTarget(double target) {
    if (percentage == null) return false;
    return percentage! >= target;
  }

  /// Calculates how many consecutive classes need to be attended to reach [target]%
  int classesNeededForTarget(double target) {
    if (totalMarked == 0) return 0;
    if (percentage != null && percentage! >= target) return 0;
    if (target >= 100) return 1;

    final p = presentCount;
    final total = totalMarked;
    final t = target;

    // (p + x) / (total + x) >= t / 100
    // 100 * p + 100 * x >= t * total + t * x
    // (100 - t) * x >= t * total - 100 * p
    // x >= (t * total - 100 * p) / (100 - t)
    final numerator = (t * total) - (100.0 * p);
    final denominator = 100.0 - t;
    if (denominator <= 0) return 1;
    return max(0, (numerator / denominator).ceil());
  }

  /// Calculates how many classes can safely be missed while maintaining at least [target]%
  int classesCanMiss(double target) {
    if (percentage == null || percentage! < target || target <= 0) return 0;

    final p = presentCount;
    final total = totalMarked;
    final t = target;

    // p / (total + y) >= t / 100
    // 100 * p >= t * total + t * y
    // t * y <= 100 * p - t * total
    // y <= (100 * p - t * total) / t
    final numerator = (100.0 * p) - (t * total);
    return max(0, (numerator / t).floor());
  }
}

class OverallAttendanceStats {
  final int totalPresent;
  final int totalAbsent;
  final int totalUnmarked;
  final double? percentage;

  OverallAttendanceStats({
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalUnmarked,
    required this.percentage,
  });

  int get totalMarked => totalPresent + totalAbsent;
  int get totalClasses => totalPresent + totalAbsent + totalUnmarked;

  bool meetsTarget(double target) {
    if (percentage == null) return false;
    return percentage! >= target;
  }

  /// Calculates how many consecutive classes need to be attended to reach [target]%
  int classesNeededForTarget(double target) {
    if (totalMarked == 0) return 0;
    if (percentage != null && percentage! >= target) return 0;
    if (target >= 100) return 1;

    final p = totalPresent;
    final total = totalMarked;
    final t = target;

    final numerator = (t * total) - (100.0 * p);
    final denominator = 100.0 - t;
    if (denominator <= 0) return 1;
    return max(0, (numerator / denominator).ceil());
  }

  /// Calculates how many classes can safely be missed while maintaining at least [target]%
  int classesCanMiss(double target) {
    if (percentage == null || percentage! < target || target <= 0) return 0;

    final p = totalPresent;
    final total = totalMarked;
    final t = target;

    final numerator = (100.0 * p) - (t * total);
    return max(0, (numerator / t).floor());
  }
}

class AttendanceCalculator {
  static int classesNeededToReachTarget(OverallAttendanceStats stats, double target) {
    return stats.classesNeededForTarget(target);
  }

  static int classesCanSafelyMiss(OverallAttendanceStats stats, double target) {
    return stats.classesCanMiss(target);
  }
  static SubjectAttendanceStats calculateSubjectStats(List<ClassSession> sessions) {
    int present = 0;
    int absent = 0;
    int unmarked = 0;

    for (final s in sessions) {
      switch (s.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.unmarked:
          unmarked++;
          break;
      }
    }

    final totalMarked = present + absent;
    double? percentage;
    if (totalMarked > 0) {
      percentage = double.parse(((present / totalMarked) * 100.0).toStringAsFixed(1));
    }

    return SubjectAttendanceStats(
      presentCount: present,
      absentCount: absent,
      unmarkedCount: unmarked,
      percentage: percentage,
    );
  }

  static OverallAttendanceStats calculateOverallStats(List<ClassSession> allSessions) {
    int totalPresent = 0;
    int totalAbsent = 0;
    int totalUnmarked = 0;

    for (final s in allSessions) {
      switch (s.status) {
        case AttendanceStatus.present:
          totalPresent++;
          break;
        case AttendanceStatus.absent:
          totalAbsent++;
          break;
        case AttendanceStatus.unmarked:
          totalUnmarked++;
          break;
      }
    }

    final totalMarked = totalPresent + totalAbsent;
    double? percentage;
    if (totalMarked > 0) {
      percentage = double.parse(((totalPresent / totalMarked) * 100.0).toStringAsFixed(1));
    }

    return OverallAttendanceStats(
      totalPresent: totalPresent,
      totalAbsent: totalAbsent,
      totalUnmarked: totalUnmarked,
      percentage: percentage,
    );
  }
}

