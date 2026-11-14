import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Map<String, List<ClassSession>> _sessionsByDate = {};
  Map<String, List<ClassSession>> _sessionsBySubject = {};
  Map<String, Subject> _subjectsById = {};
  OverallAttendanceStats? _cachedOverallStats;
  Map<String, SubjectAttendanceStats> _cachedSubjectStats = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  Timer? _activeClassCheckTimer;
  String _lastActiveSessionHash = '';

  List<Subject> get subjects => _subjects;
  Map<String, Subject> get subjectsMap => _subjectsById;
  List<ClassSession> get allSessions => _allSessions;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;

  final _uuid = const Uuid();

  AttendanceProvider() {
    // Check for active class transitions periodically (every 15s)
    // Only triggers a rebuild if an active session actually started or ended!
    _activeClassCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final now = DateTime.now();
      final todayStr = AppDateUtils.formatDateYmd(now);
      final todaySessions = _sessionsByDate[todayStr];
      if (todaySessions == null || todaySessions.isEmpty) {
        if (_lastActiveSessionHash.isNotEmpty) {
          _lastActiveSessionHash = '';
          notifyListeners();
        }
        return;
      }
      final activeIds = todaySessions
          .where((s) => s.isCurrentlyActive(now))
          .map((s) => s.id)
          .join(',');
      if (activeIds != _lastActiveSessionHash) {
        _lastActiveSessionHash = activeIds;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _activeClassCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> loadData({bool showLoading = true, UserSettings? userSettings}) async {
    if (showLoading && _allSessions.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _subjects = await AppDatabase.instance.getAllSubjects();
      final rawSessions = await AppDatabase.instance.getAllSessions();
      if (userSettings != null && userSettings.customHolidaysSet.isNotEmpty) {
        _allSessions = rawSessions.where((s) => !userSettings.customHolidaysSet.contains(s.date)).toList();
      } else {
        _allSessions = rawSessions;
      }
      _rebuildSessionsIndex();
    } catch (e) {
      debugPrint('Error loading attendance data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _rebuildSessionsIndex() {
    final Map<String, List<ClassSession>> byDate = {};
    final Map<String, List<ClassSession>> bySubject = {};
    for (final s in _allSessions) {
      byDate.putIfAbsent(s.date, () => []).add(s);
      bySubject.putIfAbsent(s.subjectId, () => []).add(s);
    }
    for (final list in byDate.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    _sessionsByDate = byDate;
    _sessionsBySubject = bySubject;
    _subjectsById = {for (var s in _subjects) s.id: s};

    // Precalculate and memoize stats so UI getters run in instant O(1)
    _cachedOverallStats = AttendanceCalculator.calculateOverallStats(_allSessions);
    final Map<String, SubjectAttendanceStats> subStats = {};
    for (final sub in _subjects) {
      subStats[sub.id] = AttendanceCalculator.calculateSubjectStats(bySubject[sub.id] ?? const []);
    }
    _cachedSubjectStats = subStats;
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // --- STATS CALCULATIONS (Instant O(1) cached access) ---

  OverallAttendanceStats get overallStats {
    return _cachedOverallStats ?? AttendanceCalculator.calculateOverallStats(_allSessions);
  }

  SubjectAttendanceStats getSubjectStats(String subjectId) {
    return _cachedSubjectStats[subjectId] ??
        AttendanceCalculator.calculateSubjectStats(_sessionsBySubject[subjectId] ?? const []);
  }

  Subject? getSubjectById(String id) {
    return _subjectsById[id];
  }

  // --- ACTIVE CLASS MODE ---

  /// Returns scheduled sessions that are currently in progress right now
  List<ClassSession> getActiveClasses([DateTime? customNow, UserSettings? settings]) {
    final now = customNow ?? DateTime.now();
    if (settings != null && settings.hasSemesterRange && !settings.isDateInSemester(now)) {
      return const [];
    }
    final todayStr = AppDateUtils.formatDateYmd(now);
    final todaySessions = _sessionsByDate[todayStr];
    if (todaySessions == null || todaySessions.isEmpty) return const [];

    return todaySessions.where((s) => s.isCurrentlyActive(now)).toList();
  }

  // --- TIMETABLE / CALENDAR HELPERS ---

  List<ClassSession> getSessionsForDate(DateTime date, [UserSettings? settings]) {
    final dateStr = AppDateUtils.formatDateYmd(date);
    final sessions = _sessionsByDate[dateStr] ?? const [];

    if (settings != null) {
      final examSessions = sessions.where((s) => s.isExamSession).toList();
      if (settings.hasSemesterRange && !settings.isDateInSemester(date)) {
        // Exam sessions and finals are never hidden, even outside semester range!
        return examSessions;
      }
      if (HolidayUtils.isHoliday(date, settings)) {
        // Exam sessions on declared off-days / holidays are also kept visible!
        return examSessions;
      }
    }
    return sessions;
  }

  bool isExamDate(DateTime date) {
    final dateStr = AppDateUtils.formatDateYmd(date);
    final sessions = _sessionsByDate[dateStr] ?? const [];
    return sessions.any((s) => s.isExamSession);
  }

  List<ClassSession> getSessionsForSubject(String subjectId) {
    return _sessionsBySubject[subjectId] ?? const [];
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
  /// 'future': Scheduled classes in future or exam day
  /// 'none': No classes scheduled (or outside semester)
  String getDateStatus(DateTime date, [UserSettings? settings]) {
    final sessions = getSessionsForDate(date, settings);
    if (sessions.isEmpty) return 'none';

    // If day contains exams, indicate as active future / exam day
    if (sessions.any((s) => s.isExamSession)) {
      return 'future';
    }

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
      _rebuildSessionsIndex();
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
    _rebuildSessionsIndex();
    notifyListeners();

    if ((userSettings?.notificationsEnabled ?? true) &&
        !(userSettings?.isSemesterEnded ?? false) &&
        (userSettings == null || userSettings.isDateInSemester(session.startDateTime))) {
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

    // 2. Terminate exams that conflict with new semester bounds
    await pruneExamsOnSemesterBoundsChanged(
      newStartDateStr: sStr,
      newEndDateStr: eStr,
      settings: userSettings,
    );

    // 3. Fetch any explicit rules from DB
    final dbRules = await AppDatabase.instance.getAllScheduleRules();

    // 4. Derive recurring weekly templates from rules and existing sessions
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
      if (s.isExamSession) continue; // CRITICAL: Exam sessions must NEVER become recurring weekly templates!
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
    _rebuildSessionsIndex();
    notifyListeners();
  }

  Future<void> updateSessionDetails(ClassSession session) async {
    await AppDatabase.instance.updateSession(session);
    final idx = _allSessions.indexWhere((s) => s.id == session.id);
    if (idx != -1) {
      _allSessions[idx] = session;
      _rebuildSessionsIndex();
    }
    notifyListeners();
  }

  /// Syncs notifications for all upcoming classes (next 14 days) in AlarmManager
  Future<void> syncAllUpcomingNotifications(UserSettings settings) async {
    if (!settings.notificationsEnabled) {
      await NotificationService.instance.cancelAll();
      return;
    }

    if (settings.isSemesterEnded) {
      await NotificationService.instance.cancelAll();
      await NotificationService.instance.checkAndShowSemesterCompletionNotification(
        settings: settings,
        allSessions: _allSessions,
      );
      return;
    }

    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 14));

    final upcomingSessions = _allSessions.where((s) {
      if (s.status != AttendanceStatus.unmarked) return false;
      if (s.endDateTime.isBefore(now)) return false;
      if (!settings.isDateInSemester(s.startDateTime)) return false;
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

    // Schedule congratulations notification for 1 hour after the semester's last class
    await NotificationService.instance.scheduleSemesterCompletionNotification(
      settings: settings,
      allSessions: _allSessions,
    );
  }

  Future<void> rescheduleAllNotifications(UserSettings settings) async {
    await NotificationService.instance.cancelAll();
    await syncAllUpcomingNotifications(settings);
  }

  /// Remove all scheduled classes on a declared holiday date and recalculate stats
  Future<int> removeClassesOnHoliday(String ymd, UserSettings settings) async {
    final sessions = _sessionsByDate[ymd] ?? [];
    for (final s in sessions) {
      await NotificationService.instance.cancelSessionReminder(s.id);
    }
    final deleted = await AppDatabase.instance.deleteSessionsForDate(ymd);
    await loadData(showLoading: false, userSettings: settings);
    await syncAllUpcomingNotifications(settings);
    return deleted;
  }

  static const String _prefKeyExamSchedule = 'saved_exam_schedule_config_v2';
  static const String _prefKeyFinalsSchedule = 'saved_finals_schedule_config_v2';

  Future<Map<String, dynamic>?> getSavedExamSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefKeyExamSchedule);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveExamSchedule(Map<String, dynamic> config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyExamSchedule, jsonEncode(config));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getSavedFinalsSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefKeyFinalsSchedule);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveFinalsSchedule(Map<String, dynamic> config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyFinalsSchedule, jsonEncode(config));
    } catch (_) {}
  }

  Future<int> restoreRegularClassesForDates(List<String> dateStrs, UserSettings settings) async {
    if (dateStrs.isEmpty) return 0;
    final dbRules = await AppDatabase.instance.getAllScheduleRules();
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
      if (s.isExamSession) continue;
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

    if (templates.isEmpty) return 0;

    int restoredCount = 0;
    for (final dateStr in dateStrs) {
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;

      if (HolidayUtils.isHoliday(dt, settings)) continue;
      if (settings.hasSemesterRange && !settings.isDateInSemester(dt)) continue;

      final existingSessions = _sessionsByDate[dateStr] ?? [];
      final existingKeys = {
        for (final s in existingSessions) '${s.subjectId}|${s.startTime}'
      };

      for (final t in templates.values) {
        if (t.weekday == dt.weekday) {
          final key = '${t.subjectId}|${t.startTime}';
          if (!existingKeys.contains(key)) {
            existingKeys.add(key);
            final session = ClassSession(
              id: const Uuid().v4(),
              subjectId: t.subjectId,
              date: dateStr,
              startTime: t.startTime,
              endTime: t.endTime,
              room: t.room,
              status: AttendanceStatus.unmarked,
              isExam: false,
            );
            await AppDatabase.instance.insertSession(session);
            restoredCount++;
          }
        }
      }
    }
    return restoredCount;
  }

  /// Apply Exam Schedule & In-Between Holiday Leave
  Future<Map<String, int>> applyExamSchedule({
    required bool isHalfDay,
    required String? examStartTime,
    required String? examEndTime,
    required List<Map<String, dynamic>> exams, // each: {'date': ymd, 'subjectId': id, 'room': room}
    required bool excludeGapDays,
    required bool createExamSessions,
    required UserSettings settings,
    required Future<void> Function(List<String> holidaysToAdd) onHolidaysAdded,
    required Future<void> Function(List<String> holidaysToRemove) onHolidaysRemoved,
  }) async {
    // 0. Compare with previously saved exam schedule to restore dates that were removed or changed!
    final prevConfig = await getSavedExamSchedule();
    final prevExamDates = (prevConfig?['exams'] as List?)
            ?.map((e) => (e as Map)['date'] as String)
            .toSet() ??
        <String>{};
    final prevGapHolidays = (prevConfig?['gapHolidays'] as List?)
            ?.cast<String>()
            .toSet() ??
        <String>{};

    final newExamDateStrs = exams.map((e) => e['date'] as String).toSet();
    final newGapDatesToAdd = <String>[];

    // Compute new gap days if toggle is ON and at least 2 exams
    if (excludeGapDays && exams.length >= 2) {
      final sortedExamDates = exams.map((e) => DateTime.parse(e['date'] as String)).toList()..sort();
      final firstDate = sortedExamDates.first;
      final lastDate = sortedExamDates.last;

      var cur = firstDate.add(const Duration(days: 1));
      while (cur.isBefore(lastDate)) {
        final ymd = AppDateUtils.formatDateYmd(cur);
        if (!newExamDateStrs.contains(ymd)) {
          newGapDatesToAdd.add(ymd);
        }
        cur = cur.add(const Duration(days: 1));
      }
    }

    final newGapDateStrs = newGapDatesToAdd.toSet();

    // Identify dates that were previously exams or gap holidays, but are NO LONGER in the schedule
    final oldActiveDates = <String>{...prevExamDates, ...prevGapHolidays};
    final newActiveDates = <String>{...newExamDateStrs, ...newGapDateStrs};
    final datesToRestore = oldActiveDates.difference(newActiveDates).toList();

    // 1. Clean up old dates that were removed
    if (datesToRestore.isNotEmpty) {
      for (final dateStr in datesToRestore) {
        if (prevExamDates.contains(dateStr)) {
          await AppDatabase.instance.deleteExamSessionsForDate(dateStr);
        }
      }
      final holidaysToRemove = datesToRestore.where((d) => prevGapHolidays.contains(d)).toList();
      if (holidaysToRemove.isNotEmpty) {
        await onHolidaysRemoved(holidaysToRemove);
      }
      await restoreRegularClassesForDates(datesToRestore, settings);
    }

    int conflictingClassesRemoved = 0;
    int examSessionsCreated = 0;
    int gapHolidaysAdded = 0;

    // Clear existing exam sessions on all new exam dates first before inserting
    for (final d in newExamDateStrs) {
      await AppDatabase.instance.deleteExamSessionsForDate(d);
    }

    // 2. Process each new exam date
    for (final exam in exams) {
      final dateStr = exam['date'] as String;
      final subjectId = exam['subjectId'] as String;
      final room = (exam['room'] as String?)?.trim().isNotEmpty == true
          ? (exam['room'] as String).trim()
          : 'Exam Hall';

      if (!isHalfDay) {
        // Full-day exam: Remove all regular non-exam classes on that date
        final deleted = await AppDatabase.instance.deleteNonExamSessionsForDate(dateStr);
        conflictingClassesRemoved += deleted;
      } else {
        // Half-day exam: Remove regular classes overlapping with exam hours
        final startTime = examStartTime ?? '09:30';
        final endTime = examEndTime ?? '12:30';
        final deleted = await AppDatabase.instance.deleteNonExamSessionsOverlappingTime(dateStr, startTime, endTime);
        conflictingClassesRemoved += deleted;
      }

      if (createExamSessions) {
        final examSession = ClassSession(
          id: const Uuid().v4(),
          subjectId: subjectId,
          date: dateStr,
          startTime: isHalfDay ? (examStartTime ?? '09:30') : '10:00',
          endTime: isHalfDay ? (examEndTime ?? '12:30') : '13:00',
          room: room,
          status: AttendanceStatus.unmarked,
          isExam: true,
        );
        await AppDatabase.instance.insertSession(examSession);
        examSessionsCreated++;
      }
    }

    // 3. Process new gap days
    if (newGapDatesToAdd.isNotEmpty) {
      for (final gapYmd in newGapDatesToAdd) {
        final deleted = await AppDatabase.instance.deleteNonExamSessionsForDate(gapYmd);
        conflictingClassesRemoved += deleted;
        gapHolidaysAdded++;
      }
      await onHolidaysAdded(newGapDatesToAdd);
    }

    // 4. Save active configuration
    await saveExamSchedule({
      'isHalfDay': isHalfDay,
      'examStartTime': examStartTime,
      'examEndTime': examEndTime,
      'excludeGapDays': excludeGapDays,
      'exams': exams,
      'gapHolidays': newGapDatesToAdd,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // 5. Reload data and sync notifications
    await loadData(showLoading: false, userSettings: settings);
    await syncAllUpcomingNotifications(settings);

    return {
      'removed': conflictingClassesRemoved,
      'exams': examSessionsCreated,
      'gaps': gapHolidaysAdded,
      'restored': datesToRestore.length,
    };
  }

  /// Reset / Clear Exam Schedule and restore all regular classes
  Future<void> clearExamSchedule({
    required UserSettings settings,
    required Future<void> Function(List<String> holidaysToRemove) onHolidaysRemoved,
  }) async {
    final prevConfig = await getSavedExamSchedule();
    if (prevConfig == null) return;

    final prevExamDates = (prevConfig['exams'] as List?)
            ?.map((e) => (e as Map)['date'] as String)
            .toSet() ??
        <String>{};
    final prevGapHolidays = (prevConfig['gapHolidays'] as List?)
            ?.cast<String>()
            .toSet() ??
        <String>{};

    final allDates = <String>{...prevExamDates, ...prevGapHolidays}.toList();

    for (final d in prevExamDates) {
      await AppDatabase.instance.deleteExamSessionsForDate(d);
    }
    if (prevGapHolidays.isNotEmpty) {
      await onHolidaysRemoved(prevGapHolidays.toList());
    }

    await restoreRegularClassesForDates(allDates, settings);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyExamSchedule);

    await loadData(showLoading: false, userSettings: settings);
    await syncAllUpcomingNotifications(settings);
  }

  /// Apply Semester End Finals Schedule (Theory & Lab Exams)
  Future<int> applyFinalsSchedule({
    required List<Map<String, dynamic>> finals,
    required UserSettings settings,
  }) async {
    // 1. Gather all dates from previous saved finals AND new finals
    final prevSaved = await getSavedFinalsSchedule();
    final prevDates = (prevSaved?['finals'] as List?)
            ?.map((e) => (e as Map)['date'] as String)
            .toSet() ??
        <String>{};
    final newDates = finals.map((e) => e['date'] as String).toSet();
    final allDatesToClean = {...prevDates, ...newDates};

    // 2. Clear ALL existing exam sessions on all affected dates BEFORE the insertion loop
    for (final d in allDatesToClean) {
      await AppDatabase.instance.deleteExamSessionsForDate(d);
    }

    // 3. Insert all new final exam sessions (both lab and theory)
    int created = 0;
    for (final exam in finals) {
      final ymd = exam['date'] as String;
      final subjectId = exam['subjectId'] as String;
      final kindStr = exam['kind'] as String? ?? 'theory';
      final kindLabel = kindStr == 'lab' ? 'Lab Exam' : 'Theory Exam';
      final location = (exam['location'] as String?)?.trim().isNotEmpty == true
          ? (exam['location'] as String).trim()
          : (kindStr == 'lab' ? 'Lab Room' : 'Exam Hall');
      final startTime = exam['startTime'] as String? ?? (kindStr == 'lab' ? '09:30' : '10:00');
      final endTime = exam['endTime'] as String? ?? (kindStr == 'lab' ? '12:30' : '13:00');

      final session = ClassSession(
        id: const Uuid().v4(),
        subjectId: subjectId,
        date: ymd,
        startTime: startTime,
        endTime: endTime,
        room: '$location • $kindLabel',
        status: AttendanceStatus.unmarked,
        isExam: true,
      );
      await AppDatabase.instance.insertSession(session);
      created++;
    }

    // 4. Save configuration
    await saveFinalsSchedule({
      'finals': finals,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // 5. Reload data
    await loadData(showLoading: false, userSettings: settings);
    await syncAllUpcomingNotifications(settings);
    return created;
  }

  /// Reset / Clear Semester Finals Schedule
  Future<void> clearFinalsSchedule({required UserSettings settings}) async {
    final prevSaved = await getSavedFinalsSchedule();
    final prevDates = (prevSaved?['finals'] as List?)
            ?.map((e) => (e as Map)['date'] as String)
            .toSet() ??
        <String>{};

    for (final d in prevDates) {
      await AppDatabase.instance.deleteExamSessionsForDate(d);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyFinalsSchedule);

    await loadData(showLoading: false, userSettings: settings);
    await syncAllUpcomingNotifications(settings);
  }

  /// Prunes / terminates exams when semester bounds are changed:
  /// 1. Finals (theory/lab exams) that now fall inside the active semester (date <= newEndDateStr && date >= newStartDateStr) are terminated.
  /// 2. Mid-semester exams that now fall outside the new semester bounds (date < newStartDateStr || date > newEndDateStr) are terminated.
  Future<void> pruneExamsOnSemesterBoundsChanged({
    required String newStartDateStr,
    required String newEndDateStr,
    UserSettings? settings,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // A. Check Semester Finals: finals cannot be inside the semester
    final savedFinals = await getSavedFinalsSchedule();
    if (savedFinals != null) {
      final rawList = savedFinals['finals'] as List? ?? [];
      final updatedFinals = <Map<String, dynamic>>[];
      final terminatedFinalDates = <String>[];

      for (final item in rawList) {
        if (item is Map) {
          final dStr = item['date'] as String?;
          if (dStr != null) {
            // If this final exam now falls inside the semester bounds, terminate it!
            if (dStr.compareTo(newStartDateStr) >= 0 && dStr.compareTo(newEndDateStr) <= 0) {
              terminatedFinalDates.add(dStr);
              await AppDatabase.instance.deleteExamSessionsForDate(dStr);
            } else {
              updatedFinals.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }

      if (updatedFinals.isEmpty) {
        await prefs.remove(_prefKeyFinalsSchedule);
      } else if (terminatedFinalDates.isNotEmpty) {
        await saveFinalsSchedule({
          'finals': updatedFinals,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    }

    // B. Check Midterm / Inside-Semester Exams: midterms cannot be outside the semester bounds
    final savedExams = await getSavedExamSchedule();
    if (savedExams != null) {
      final rawExams = savedExams['exams'] as List? ?? [];
      final updatedExams = <Map<String, dynamic>>[];
      final terminatedExamDates = <String>[];

      for (final item in rawExams) {
        if (item is Map) {
          final dStr = item['date'] as String?;
          if (dStr != null) {
            // If mid-semester exam now falls OUTSIDE the semester bounds, terminate it!
            if (dStr.compareTo(newStartDateStr) < 0 || dStr.compareTo(newEndDateStr) > 0) {
              terminatedExamDates.add(dStr);
              await AppDatabase.instance.deleteExamSessionsForDate(dStr);
            } else {
              updatedExams.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }

      if (updatedExams.isEmpty) {
        await prefs.remove(_prefKeyExamSchedule);
      } else if (terminatedExamDates.isNotEmpty) {
        final newConfig = Map<String, dynamic>.from(savedExams);
        newConfig['exams'] = updatedExams;
        newConfig['updatedAt'] = DateTime.now().toIso8601String();
        await saveExamSchedule(newConfig);
      }
    }
  }
}
