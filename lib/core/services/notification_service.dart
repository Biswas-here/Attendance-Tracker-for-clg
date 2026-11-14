import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../database/app_database.dart';
import '../models/class_session.dart';
import '../models/user_settings.dart';
import '../utils/date_utils.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  WidgetsFlutterBinding.ensureInitialized();
  final actionId = notificationResponse.actionId;
  final rawPayload = notificationResponse.payload;

  if (rawPayload != null && actionId != null) {
    String sessionId = rawPayload;
    if (rawPayload.startsWith('unmarked:')) {
      final parts = rawPayload.split(':');
      if (parts.length >= 3) {
        sessionId = parts[2];
      }
    } else if (rawPayload.startsWith('session:') || rawPayload.startsWith('advance:')) {
      final parts = rawPayload.split(':');
      if (parts.length >= 2) {
        sessionId = parts[1];
      }
    }

    final status = actionId == 'action_present'
        ? AttendanceStatus.present
        : actionId == 'action_absent'
            ? AttendanceStatus.absent
            : null;

    if (status != null) {
      await AppDatabase.instance.updateSessionStatus(sessionId, status);

      // Cancel all scheduled/active notifications for this session
      final plugin = FlutterLocalNotificationsPlugin();
      final baseId = (sessionId.hashCode.abs() % 500000000) * 4;
      for (int i = 0; i < 4; i++) {
        await plugin.cancel(id: baseId + i);
      }
    }
  }
}

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  static final ValueNotifier<String?> onNotificationPayload = ValueNotifier<String?>(null);

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  NotificationService._init();

  static const String _channelId = 'class_attendance_channel_v2';
  static const String _channelName = 'Class Attendance Reminders';
  static const String _channelDescription =
      'Reminders to mark attendance for scheduled classes';

  Future<void> init({Function(String sessionId)? onNotificationTapped}) async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    // Configure exact local timezone using flutter_timezone
    try {
      final tzResult = await FlutterTimezone.getLocalTimezone();
      final timeZoneName = tzResult.toString();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Error getting local timezone: $e');
      try {
        final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.currentTimeZone.offset.inMilliseconds == offsetMs) {
            tz.setLocalLocation(loc);
            break;
          }
        }
      } catch (fallbackError) {
        debugPrint('Fallback timezone error: $fallbackError');
      }
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) async {
        final actionId = response.actionId;
        final rawPayload = response.payload;

        if (rawPayload != null) {
          String sessionId = rawPayload;
          if (rawPayload.startsWith('unmarked:')) {
            final parts = rawPayload.split(':');
            if (parts.length >= 3) {
              sessionId = parts[2];
            }
          } else if (rawPayload.startsWith('session:') || rawPayload.startsWith('advance:')) {
            final parts = rawPayload.split(':');
            if (parts.length >= 2) {
              sessionId = parts[1];
            }
          }

          if (actionId == 'action_present') {
            await AppDatabase.instance.updateSessionStatus(sessionId, AttendanceStatus.present);
            await cancelSessionReminder(sessionId);
          } else if (actionId == 'action_absent') {
            await AppDatabase.instance.updateSessionStatus(sessionId, AttendanceStatus.absent);
            await cancelSessionReminder(sessionId);
          } else {
            onNotificationPayload.value = rawPayload;
            if (onNotificationTapped != null) {
              onNotificationTapped(rawPayload);
            }
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create high-importance notification channel on Android
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Recreate channel with highest importance, sound, and vibration
        try {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            ),
          );
        } catch (e) {
          debugPrint('Error creating notification channel: $e');
        }

        // Request notifications & exact alarms automatically on init
        try {
          await androidPlugin.requestNotificationsPermission();
        } catch (_) {}
        try {
          await androidPlugin.requestExactAlarmsPermission();
        } catch (_) {}
      }
    }

    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return false;
  }

  Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestExactAlarmsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting exact alarm permission: $e');
    }
    return false;
  }

  int _baseId(String sessionId) => (sessionId.hashCode.abs() % 500000000) * 4;

  /// Schedule all reminders for a class session:
  /// 1. Advance reminder (e.g. 5 or 10 mins before start)
  /// 2. Class start reminder (at start time) with PRESENT / ABSENT actions
  /// 3. Class end unmarked reminder (at end time) with PRESENT / ABSENT actions
  Future<void> scheduleSessionReminder({
    required ClassSession session,
    required String subjectName,
    String? room,
    int advanceMinutes = 5,
  }) async {
    // If session is already marked, don't schedule reminders
    if (session.status != AttendanceStatus.unmarked) {
      await cancelSessionReminder(session.id);
      return;
    }

    final now = DateTime.now();
    final startDt = session.startDateTime;
    final endDt = session.endDateTime;
    final baseId = _baseId(session.id);
    final roomInfo = (room != null && room.trim().isNotEmpty) ? ' • $room' : '';

    // 1. Advance reminder (e.g. 5 minutes before class)
    if (advanceMinutes > 0) {
      final advanceDt = startDt.subtract(Duration(minutes: advanceMinutes));
      if (advanceDt.isAfter(now)) {
        await _scheduleSingleNotification(
          id: baseId,
          scheduledDate: advanceDt,
          title: 'Upcoming: $subjectName in $advanceMinutes mins',
          body: 'Class starts at ${session.startTime}$roomInfo. Tap to open schedule.',
          sessionId: 'advance:${session.id}',
          includeActions: false,
        );
      }
    }

    // 2. Class start reminder (at start time) with Present / Absent quick actions
    // Redesigned: Clear subject title, simple present/absent instruction, no cluttered room/time text
    if (startDt.isAfter(now)) {
      await _scheduleSingleNotification(
        id: baseId + 1,
        scheduledDate: startDt,
        title: subjectName,
        body: 'Mark Attendance: Present or Absent',
        sessionId: 'session:${session.id}',
        includeActions: true,
      );
    }

    // 3. Class end unmarked reminder: fires once class ends if still unmarked
    if (endDt.isAfter(now)) {
      await _scheduleSingleNotification(
        id: baseId + 2,
        scheduledDate: endDt,
        title: 'Unmarked: $subjectName (${session.date})',
        body: 'Class ended at ${session.endTime}$roomInfo. Did you attend? Tap PRESENT or ABSENT.',
        sessionId: 'unmarked:${session.date}:${session.id}',
        includeActions: true,
      );
    }
  }

  /// Clears active fired reminders (upcoming and class start) upon entering the app,
  /// but ONLY for classes that have already started, keeping upcoming future alarms intact.
  /// Also preserves scheduled class end unmarked reminders.
  Future<void> clearActiveFiredReminders({required List<ClassSession> allSessions}) async {
    final now = DateTime.now();
    for (final s in allSessions) {
      final base = _baseId(s.id);

      // If the class has already started in the past, dismiss active reminders from the shade
      if (s.startDateTime.isBefore(now)) {
        try {
          // Dismiss advance reminder
          await _notificationsPlugin.cancel(id: base);
          // Dismiss class start reminder
          await _notificationsPlugin.cancel(id: base + 1);
        } catch (_) {}
      }

      // If the session is already marked, also dismiss any end-of-class notification
      if (s.status != AttendanceStatus.unmarked) {
        try {
          await _notificationsPlugin.cancel(id: base + 2);
          await _notificationsPlugin.cancel(id: base + 3);
        } catch (_) {}
      }
    }
  }

  /// Sync notifications for past unmarked classes that already ended.
  Future<void> syncUnmarkedClassNotifications({
    required List<ClassSession> allSessions,
    required Map<String, String> subjectNames,
    UserSettings? settings,
  }) async {
    if (settings != null && (!settings.notificationsEnabled || settings.isSemesterEnded)) {
      return;
    }
    final now = DateTime.now();
    final todayStr = AppDateUtils.formatDateYmd(now);

    final prefs = await SharedPreferences.getInstance();
    const notifiedKey = 'notified_unmarked_sessions';
    final notifiedIds = (prefs.getStringList(notifiedKey) ?? <String>[]).toSet();

    for (final s in allSessions) {
      if (settings != null && !settings.isDateInSemester(s.startDateTime)) {
        continue;
      }
      final isToday = s.date == todayStr;
      final hasEnded = s.endDateTime.isBefore(now);
      final isUnmarked = s.status == AttendanceStatus.unmarked;

      if (isToday && hasEnded && isUnmarked) {
        if (notifiedIds.contains(s.id)) continue;

        final subName = subjectNames[s.subjectId] ?? 'Class';
        final notifId = _baseId(s.id) + 3;
        final payload = 'unmarked:${s.date}:${s.id}';

        try {
          await _notificationsPlugin.show(
            id: notifId,
            title: 'Unmarked: $subName (${s.date})',
            body: 'You haven\'t marked attendance for $subName (${s.startTime} - ${s.endTime}). Tap PRESENT or ABSENT.',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: _channelDescription,
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
                visibility: NotificationVisibility.public,
                category: AndroidNotificationCategory.reminder,
                onlyAlertOnce: true,
                ongoing: false,
                autoCancel: true,
                actions: <AndroidNotificationAction>[
                  AndroidNotificationAction(
                    'action_present',
                    'PRESENT',
                    showsUserInterface: false,
                    cancelNotification: true,
                  ),
                  AndroidNotificationAction(
                    'action_absent',
                    'ABSENT',
                    showsUserInterface: false,
                    cancelNotification: true,
                  ),
                ],
              ),
            ),
            payload: payload,
          );

          notifiedIds.add(s.id);
          await prefs.setStringList(notifiedKey, notifiedIds.toList());
        } catch (_) {}
      } else if (!isUnmarked) {
        await cancelUnmarkedNotification(s.id);
      }
    }
  }

  Future<void> cancelUnmarkedNotification(String sessionId) async {
    try {
      final notifId = _baseId(sessionId) + 2;
      final immediateId = _baseId(sessionId) + 3;
      await _notificationsPlugin.cancel(id: notifId);
      await _notificationsPlugin.cancel(id: immediateId);
    } catch (_) {}
  }

  Future<void> _scheduleSingleNotification({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
    required String sessionId,
    required bool includeActions,
  }) async {
    try {
      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
      if (tzDateTime.isBefore(tz.TZDateTime.now(tz.local))) return;

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: title,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
        autoCancel: true,
        actions: includeActions
            ? <AndroidNotificationAction>[
                const AndroidNotificationAction(
                  'action_present',
                  'PRESENT',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
                const AndroidNotificationAction(
                  'action_absent',
                  'ABSENT',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
              ]
            : null,
      );

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDateTime,
        notificationDetails: NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: sessionId,
      );
    } catch (e) {
      debugPrint('Error scheduling exact notification: $e. Retrying inexact.');
      try {
        final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
        if (tzDateTime.isBefore(tz.TZDateTime.now(tz.local))) return;

        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDateTime,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              visibility: NotificationVisibility.public,
              category: AndroidNotificationCategory.reminder,
              autoCancel: true,
              actions: includeActions
                  ? <AndroidNotificationAction>[
                      const AndroidNotificationAction(
                        'action_present',
                        'PRESENT',
                        showsUserInterface: false,
                        cancelNotification: true,
                      ),
                      const AndroidNotificationAction(
                        'action_absent',
                        'ABSENT',
                        showsUserInterface: false,
                        cancelNotification: true,
                      ),
                    ]
                  : null,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: sessionId,
        );
      } catch (fallbackError) {
        debugPrint('Fallback notification failed: $fallbackError');
      }
    }
  }

  static const int semesterCompletionNotificationId = 888888;

  /// Schedule congratulations notification for 1 hour after the last class of the semester
  Future<void> scheduleSemesterCompletionNotification({
    required UserSettings settings,
    required List<ClassSession> allSessions,
  }) async {
    if (!settings.notificationsEnabled || !settings.hasSemesterRange) return;

    final endStr = settings.semesterEndDate;
    if (endStr == null || endStr.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final notifKey = 'semester_completion_notified_$endStr';
    if (prefs.getBool(notifKey) == true) return;

    final now = DateTime.now();

    // Find sessions belonging to this semester
    final semesterSessions = allSessions.where((s) => settings.isDateInSemester(s.startDateTime)).toList();

    DateTime completionTime;
    if (semesterSessions.isNotEmpty) {
      final lastSession = semesterSessions.reduce((a, b) => a.endDateTime.isAfter(b.endDateTime) ? a : b);
      completionTime = lastSession.endDateTime.add(const Duration(hours: 1));
    } else {
      final endDate = settings.semesterEndDateTime;
      if (endDate == null) return;
      completionTime = DateTime(endDate.year, endDate.month, endDate.day, 18, 0);
    }

    if (completionTime.isAfter(now)) {
      await _scheduleSingleNotification(
        id: semesterCompletionNotificationId,
        scheduledDate: completionTime,
        title: 'Congratulations! 🎓',
        body: 'Semester completed! You\'ve finished all your classes.',
        sessionId: 'semester_completed:$endStr',
        includeActions: false,
      );
    }
  }

  /// If user opened the app and viewed the in-app congratulations message,
  /// cancel any pending scheduled push notification and mark it as handled so it never fires.
  Future<void> dismissSemesterCompletionNotification(String semesterEndDate) async {
    try {
      await _notificationsPlugin.cancel(id: semesterCompletionNotificationId);
      final prefs = await SharedPreferences.getInstance();
      final notifKey = 'semester_completion_notified_$semesterEndDate';
      await prefs.setBool(notifKey, true);
    } catch (e) {
      debugPrint('Error dismissing semester completion notification: $e');
    }
  }

  /// Show the semester completion congratulations notification immediately
  Future<void> showSemesterCompletionNotification({
    required String semesterEndDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final notifKey = 'semester_completion_notified_$semesterEndDate';
    if (prefs.getBool(notifKey) == true) return;

    try {
      await _notificationsPlugin.show(
        id: semesterCompletionNotificationId,
        title: 'Congratulations! 🎓',
        body: 'Semester completed! You\'ve finished all your classes.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.status,
            autoCancel: true,
          ),
        ),
        payload: 'semester_completed:$semesterEndDate',
      );
      await prefs.setBool(notifKey, true);
    } catch (e) {
      debugPrint('Error showing semester completion notification: $e');
    }
  }

  /// When user opens the app and semester is completed, dismiss pending notification
  /// since the user is actively viewing the in-app congratulations message.
  Future<void> checkAndShowSemesterCompletionNotification({
    required UserSettings settings,
    required List<ClassSession> allSessions,
  }) async {
    if (!settings.hasSemesterRange) return;
    final endStr = settings.semesterEndDate;
    if (endStr == null || endStr.isEmpty) return;

    await dismissSemesterCompletionNotification(endStr);
  }

  Future<void> cancelSessionReminder(String sessionId) async {
    try {
      final baseId = _baseId(sessionId);
      for (int i = 0; i < 4; i++) {
        await _notificationsPlugin.cancel(id: baseId + i);
      }
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }
}
