import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';
import '../core/models/subject.dart';
import '../core/models/class_session.dart';
import '../core/models/user_settings.dart';
import '../core/services/notification_service.dart';
import '../core/utils/attendance_calculator.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/holiday_utils.dart';

class AttendanceProvider with ChangeNotifier {
  List<Subject> _subjects = [];
  List<ClassSession> _allSessions = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  Timer? _activeClassCheckTimer;

  List<Subject> get subjects => _subjects;
  List<ClassSession> get allSessions => _allSessions;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;

  final _uuid = const Uuid();

  AttendanceProvider() {
    // Check for active classes periodically every 30 seconds
    _activeClassCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _activeClassCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> loadData({bool showLoading = true}) async {
    if (showLoading && _allSessions.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _subjects = await AppDatabase.instance.getAllSubjects();
      _allSessions = await AppDatabase.instance.getAllSessions();
    } catch (e) {
      debugPrint('Error loading attendance data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // --- STATS CALCULATIONS ---

  OverallAttendanceStats get overallStats {
    return AttendanceCalculator.calculateOverallStats(_allSessions);
  }

  SubjectAttendanceStats getSubjectStats(String subjectId) {
    final subSessions = _allSessions.where((s) => s.subjectId == subjectId).toList();
    return AttendanceCalculator.calculateSubjectStats(subSessions);
  }

  Subject? getSubjectById(String id) {
    try {
      return _subjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // --- ACTIVE CLASS MODE ---

  /// Returns scheduled sessions that are currently in progress right now
  List<ClassSession> getActiveClasses([DateTime? customNow, UserSettings? settings]) {
    final now = customNow ?? DateTime.now();
    if (settings != null && settings.hasSemesterRange && !settings.isDateInSemester(now)) {
      return [];
    }
    final todayStr = AppDateUtils.formatDateYmd(now);

    return _allSessions.where((s) {
      if (s.date != todayStr) return false;
      return s.isCurrentlyActive(now);
    }).toList();
  }

  // --- TIMETABLE / CALENDAR HELPERS ---

  List<ClassSession> getSessionsForDate(DateTime date, [UserSettings? settings]) {
    if (settings != null && settings.hasSemesterRange && !settings.isDateInSemester(date)) {
      return [];
    }
    final dateStr = AppDateUtils.formatDateYmd(date);
    return _allSessions.where((s) => s.date == dateStr).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<ClassSession> get sessionsForSelectedDate => getSessionsForSelectedDate();

  List<ClassSession> getSessionsForSelectedDate([UserSettings? settings]) {
    return getSessionsForDate(_selectedDate, settings);
  }

  /// Calendar indicator status:
  /// 'green': All scheduled classes were attended
  /// 'red': At least one scheduled class was marked absent
  /// 'partial': Some classes marked, some unmarked
  /// 'unmarked': Scheduled classes exist, but none marked yet
  /// 'none': No classes scheduled (or outside semester)
  String getDateStatus(DateTime date, [UserSettings? settings]) {
    if (settings != null && settings.hasSemesterRange && !settings.isDateInSemester(date)) {
      return 'none';
    }

    final sessions = getSessionsForDate(date, settings);
    if (sessions.isEmpty) return 'none';

    final now = DateTime.now();
    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));
    if (isFuture) {
      // Future dates are not absences
      return 'future';
    }

    int present = 0;
    int absent = 0;
    int unmarked = 0;

    for (final s in sessions) {
      if (s.status == AttendanceStatus.present) present++;
      if (s.status == AttendanceStatus.absent) absent++;
      if (s.status == AttendanceStatus.unmarked) unmarked++;
    }

    if (absent > 0) return 'red';
    if (unmarked == 0 && present > 0) return 'green';
    if (unmarked > 0 && present > 0) return 'partial';
    return 'unmarked';
  }

  // --- SUBJECT OPERATIONS ---

  Future<String?> addSubject({
    required String name,
    String? code,
    String? teacher,
    String? room,
    double? targetPercentage,
    int? colorValue,
    bool allowDuplicate = false,
  }) async {
    final trimmedName = name.trim();
    if (!allowDuplicate) {
      final existing = await AppDatabase.instance.getSubjectByName(trimmedName);
      if (existing != null) {
        return 'duplicate';
      }
    }

    final newSubject = Subject(
      id: _uuid.v4(),
      name: trimmedName,
      code: code?.trim().isEmpty == true ? null : code?.trim(),
      teacher: teacher?.trim().isEmpty == true ? null : teacher?.trim(),
      room: room?.trim().isEmpty == true ? null : room?.trim(),
      targetPercentage: targetPercentage,
      colorValue: colorValue ?? 0xFF3F7E7D,
    );

    await AppDatabase.instance.insertSubject(newSubject);
    await loadData();
    return null;
  }

  Future<void> updateSubject(Subject subject) async {
    await AppDatabase.instance.updateSubject(subject);
    await loadData();
  }

  Future<void> deleteSubject(String id) async {
    // Cancel any scheduled notifications for this subject's sessions
    final sessionsToDelete = _allSessions.where((s) => s.subjectId == id);
    for (final s in sessionsToDelete) {
      await NotificationService.instance.cancelSessionReminder(s.id);
    }

    await AppDatabase.instance.deleteSubject(id);
    await loadData();
  }

  // --- SESSION & ATTENDANCE OPERATIONS ---

  Future<void> markAttendance(String sessionId, AttendanceStatus status) async {
    await AppDatabase.instance.updateSessionStatus(sessionId, status);

    // Update in-memory session immediately
    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final old = _allSessions[index];
      _allSessions[index] = old.copyWith(
        status: status,
        markedAt: DateTime.now(),
      );
    }
    notifyListeners();

    // If marked, cancel all reminder/unmarked notifications for this session
    if (status != AttendanceStatus.unmarked) {
      await NotificationService.instance.cancelSessionReminder(sessionId);
    } else {
      await NotificationService.instance.syncUnmarkedClassNotifications(
        allSessions: _allSessions,
        subjectNames: {for (var s in _subjects) s.id: s.name},
      );
    }
  }

  Future<void> addSingleSession({
    required String subjectId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? room,
    UserSettings? userSettings,
  }) async {
    final session = ClassSession(
      id: _uuid.v4(),
      subjectId: subjectId,
      date: AppDateUtils.formatDateYmd(date),
      startTime: startTime,
      endTime: endTime,
      room: room,
      status: AttendanceStatus.unmarked,
    );

    await AppDatabase.instance.insertSession(session);
    _allSessions.add(session);
    notifyListeners();

    if (userSettings?.notificationsEnabled ?? true) {
      final subject = getSubjectById(subjectId);
      if (subject != null) {
        await NotificationService.instance.scheduleSessionReminder(
          session: session,
          subjectName: subject.name,
          room: session.room ?? subject.room,
          advanceMinutes: userSettings?.advanceReminderEnabled == true
              ? (userSettings?.advanceReminderMinutes ?? 5)
              : 0,
        );
      }
    }
  }

  /// Batch schedule sessions across multiple dates and/or recurring rules
  Future<void> scheduleClasses({
    required List<String> subjectIds,
    required List<DateTime> dates,
    required String startTime,
    required String endTime,
    String? room,
    List<int>? recurringDaysOfWeek,
    int recurringWeeks = 1,
    UserSettings? userSettings,
  }) async {
    final List<ClassSession> newSessions = [];

    if (recurringDaysOfWeek != null && recurringDaysOfWeek.isNotEmpty) {
      // Create recurring schedule sessions starting from dates.first for recurringWeeks
      final baseDate = dates.isNotEmpty ? dates.first : DateTime.now();
      final totalDays = recurringWeeks * 7;

      for (int i = 0; i < totalDays; i++) {
        final d = baseDate.add(Duration(days: i));
        if (recurringDaysOfWeek.contains(d.weekday)) {
          final dateStr = AppDateUtils.formatDateYmd(d);
          for (final subId in subjectIds) {
            newSessions.add(ClassSession(
              id: _uuid.v4(),
              subjectId: subId,
              date: dateStr,
              startTime: startTime,
              endTime: endTime,
              room: room,
            ));
          }
        }
      }
    } else {
      // Schedule for the explicitly selected dates
      for (final date in dates) {
        final dateStr = AppDateUtils.formatDateYmd(date);
        for (final subId in subjectIds) {
          newSessions.add(ClassSession(
            id: _uuid.v4(),
            subjectId: subId,
            date: dateStr,
            startTime: startTime,
            endTime: endTime,
            room: room,
          ));
        }
      }
    }

    if (newSessions.isNotEmpty) {
      await AppDatabase.instance.insertSessionsBatch(newSessions);
      await loadData();

      // Schedule reminders for upcoming sessions
      if (userSettings?.notificationsEnabled ?? true) {
        await syncAllUpcomingNotifications(userSettings ?? UserSettings());
      }
    }
  }

  /// Extend or trim timetable classes to match the semester date range.
  /// If the semester range expands, recurring templates generate missing sessions.
  /// If the semester range contracts, unmarked sessions beyond the new range are pruned.
  Future<({int added, int removed})> syncSessionsForSemester({
    required DateTime startDate,
    required DateTime endDate,
    UserSettings? userSettings,
  }) async {
    if (endDate.isBefore(startDate)) return (added: 0, removed: 0);

    final sStr = AppDateUtils.formatDateYmd(startDate);
    final eStr = AppDateUtils.formatDateYmd(endDate);

    // 1. Remove unmarked sessions outside the new semester range
    final removed = await AppDatabase.instance.deleteUnmarkedSessionsOutsideRange(sStr, eStr);

    // 2. Fetch any explicit rules from DB
    final dbRules = await AppDatabase.instance.getAllScheduleRules();

    // 3. Derive recurring weekly templates from rules and existing sessions
    final templates = <String, ({int weekday, String startTime, String endTime, String subjectId, String? room})>{};

    for (final rule in dbRules) {
      final key = '${rule.dayOfWeek}|${rule.startTime}|${rule.endTime}|${rule.subjectId}';
      templates[key] = (
        weekday: rule.dayOfWeek,
        startTime: rule.startTime,
        endTime: rule.endTime,
        subjectId: rule.subjectId,
        room: rule.room,
      );
    }

    for (final s in _allSessions) {
      final dt = DateTime.tryParse(s.date);
      if (dt == null) continue;
      final key = '${dt.weekday}|${s.startTime}|${s.endTime}|${s.subjectId}';
      if (!templates.containsKey(key)) {
        templates[key] = (
          weekday: dt.weekday,
          startTime: s.startTime,
          endTime: s.endTime,
          subjectId: s.subjectId,
          room: s.room,
        );
      }
    }

    int added = 0;
    if (templates.isNotEmpty) {
      // Refresh current sessions
      final currentSessions = await AppDatabase.instance.getAllSessions();
      final existingFingerprints = {
        for (final s in currentSessions) '${s.subjectId}|${s.date}|${s.startTime}'
      };

      final newSessions = <ClassSession>[];
      final totalDays = endDate.difference(startDate).inDays;

      for (int i = 0; i <= totalDays; i++) {
        final curDate = startDate.add(Duration(days: i));
        final dateStr = AppDateUtils.formatDateYmd(curDate);

        // Skip holidays (Sunday always, Saturday per pattern, custom holidays)
        if (userSettings != null && HolidayUtils.isHoliday(curDate, userSettings)) {
          continue;
        }

        for (final t in templates.values) {
          if (t.weekday == curDate.weekday) {
            final fingerprint = '${t.subjectId}|$dateStr|${t.startTime}';
            if (!existingFingerprints.contains(fingerprint)) {
              existingFingerprints.add(fingerprint);
              newSessions.add(ClassSession(
                id: _uuid.v4(),
                subjectId: t.subjectId,
                date: dateStr,
                startTime: t.startTime,
                endTime: t.endTime,
                room: t.room,
                status: AttendanceStatus.unmarked,
              ));
            }
          }
        }
      }

      if (newSessions.isNotEmpty) {
        await AppDatabase.instance.insertSessionsBatch(newSessions);
        added = newSessions.length;
      }
    }

    await loadData();
    return (added: added, removed: removed);
  }

  /// Backward-compatible alias
  Future<int> extendSessionsForSemester({
    required DateTime startDate,
    required DateTime endDate,
    UserSettings? userSettings,
  }) async {
    final res = await syncSessionsForSemester(
      startDate: startDate,
      endDate: endDate,
      userSettings: userSettings,
    );
    return res.added;
  }

  /// Check if a time range overlaps with any existing sessions on the given date
  List<ClassSession> getOverlappingSessions({
    required DateTime date,
    required String startTime,
    required String endTime,
    String? excludeSessionId,
  }) {
    final dateStr = AppDateUtils.formatDateYmd(date);
    final daySessions = _allSessions.where((s) => s.date == dateStr && s.id != excludeSessionId);

    final startMinutes = _timeToMinutes(startTime);
    final endMinutes = _timeToMinutes(endTime);

    return daySessions.where((s) {
      final sStart = _timeToMinutes(s.startTime);
      final sEnd = _timeToMinutes(s.endTime);
      return startMinutes < sEnd && endMinutes > sStart;
    }).toList();
  }

  int _timeToMinutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<void> deleteSession(String sessionId) async {
    await NotificationService.instance.cancelSessionReminder(sessionId);
    await AppDatabase.instance.deleteSession(sessionId);
    _allSessions.removeWhere((s) => s.id == sessionId);
    notifyListeners();
  }

  Future<void> updateSessionDetails(ClassSession session) async {
    await AppDatabase.instance.updateSession(session);
    final idx = _allSessions.indexWhere((s) => s.id == session.id);
    if (idx != -1) {
      _allSessions[idx] = session;
    }
    notifyListeners();
  }

  /// Syncs notifications for all upcoming classes (next 14 days) in AlarmManager
  Future<void> syncAllUpcomingNotifications(UserSettings settings) async {
    if (!settings.notificationsEnabled) {
      await NotificationService.instance.cancelAll();
      return;
    }

    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 14));

    final upcomingSessions = _allSessions.where((s) {
      if (s.status != AttendanceStatus.unmarked) return false;
      if (s.endDateTime.isBefore(now)) return false;
      return s.startDateTime.isBefore(maxDate);
    }).toList();

    final subjectMap = {for (var s in _subjects) s.id: s.name};
    final roomMap = {for (var s in _subjects) s.id: s.room};

    for (final s in upcomingSessions) {
      final subjectName = subjectMap[s.subjectId] ?? 'Class';
      final room = s.room ?? roomMap[s.subjectId];
      await NotificationService.instance.scheduleSessionReminder(
        session: s,
        subjectName: subjectName,
        room: room,
        advanceMinutes: settings.advanceReminderEnabled ? settings.advanceReminderMinutes : 0,
      );
    }
  }

  Future<void> rescheduleAllNotifications(UserSettings settings) async {
    await NotificationService.instance.cancelAll();
    await syncAllUpcomingNotifications(settings);
  }
}
