import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../database/app_database.dart';
import '../models/class_session.dart';
import '../utils/date_utils.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  final actionId = notificationResponse.actionId;
  final payload = notificationResponse.payload; // sessionId

  if (payload != null && actionId != null) {
    if (actionId == 'action_present') {
      await AppDatabase.instance.updateSessionStatus(payload, AttendanceStatus.present);
    } else if (actionId == 'action_absent') {
      await AppDatabase.instance.updateSessionStatus(payload, AttendanceStatus.absent);
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
        final payload = response.payload;

        if (payload != null) {
          if (actionId == 'action_present') {
            await AppDatabase.instance.updateSessionStatus(payload, AttendanceStatus.present);
            await cancelUnmarkedNotification(payload);
          } else if (actionId == 'action_absent') {
            await AppDatabase.instance.updateSessionStatus(payload, AttendanceStatus.absent);
            await cancelUnmarkedNotification(payload);
          } else {
            onNotificationPayload.value = payload;
            if (onNotificationTapped != null) {
              onNotificationTapped(payload);
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
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'class_attendance_channel',
            'Class Attendance Reminders',
            description: 'Reminders to mark attendance for scheduled classes',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        // Request notifications & exact alarms automatically on init
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
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

  int _baseId(String sessionId) => (sessionId.hashCode.abs() % 700000000) * 3;

  /// Schedule a reminder notification for a class session
  Future<void> scheduleSessionReminder({
    required ClassSession session,
    required String subjectName,
    int advanceMinutes = 5,
  }) async {
    final now = DateTime.now();
    final startDt = session.startDateTime;
    final baseId = _baseId(session.id);

    // 1. Advance reminder (e.g. 5 minutes before class)
    if (advanceMinutes > 0) {
      final advanceDt = startDt.subtract(Duration(minutes: advanceMinutes));
      if (advanceDt.isAfter(now)) {
        await _scheduleSingleNotification(
          id: baseId,
          scheduledDate: advanceDt,
          title: 'Upcoming: $subjectName in $advanceMinutes mins',
          body: 'Class is scheduled at ${session.startTime}. Tap to open ledger.',
          sessionId: session.id,
          includeActions: false,
        );
      }
    }

    // 2. Class start reminder (at start time) with Present / Absent quick actions
    if (startDt.isAfter(now)) {
      await _scheduleSingleNotification(
        id: baseId + 1,
        scheduledDate: startDt,
        title: 'Class Time: $subjectName',
        body: '${session.startTime} - ${session.endTime}. Tap PRESENT or ABSENT.',
        sessionId: session.id,
        includeActions: true,
      );
    }
  }

  /// Clears active fired reminders (upcoming and class start) upon entering the app,
  /// but explicitly keeps unmarked notifications intact.
  Future<void> clearActiveFiredReminders({required List<ClassSession> allSessions}) async {
    for (final s in allSessions) {
      final base = _baseId(s.id);
      try {
        // Cancel advance reminder (baseId + 0)
        await _notificationsPlugin.cancel(id: base);
        // Cancel class start present/absent reminder (baseId + 1)
        await _notificationsPlugin.cancel(id: base + 1);
      } catch (_) {}
    }
  }

  /// Sync notifications for past unmarked classes.
  /// User requirement:
  /// - Only notify for the current/particular day's unmarked classes
  /// - Show each notification once only (tracked via SharedPreferences)
  /// - Dismissible by user (standard cancellable notification)
  /// - Do NOT re-alert repeatedly every time the app opens or resumes
  Future<void> syncUnmarkedClassNotifications({
    required List<ClassSession> allSessions,
    required Map<String, String> subjectNames,
  }) async {
    final now = DateTime.now();
    final todayStr = AppDateUtils.formatDateYmd(now);

    final prefs = await SharedPreferences.getInstance();
    const notifiedKey = 'notified_unmarked_sessions';
    final notifiedIds = (prefs.getStringList(notifiedKey) ?? <String>[]).toSet();

    for (final s in allSessions) {
      // Only notify for today's classes that have already ended and remain unmarked
      final isToday = s.date == todayStr;
      final hasEnded = s.endDateTime.isBefore(now);
      final isUnmarked = s.status == AttendanceStatus.unmarked;

      if (isToday && hasEnded && isUnmarked) {
        // If already notified for this session, skip so we don't spam or re-pop
        if (notifiedIds.contains(s.id)) continue;

        final subName = subjectNames[s.subjectId] ?? 'Class';
        final notifId = _baseId(s.id) + 2;
        final payload = 'unmarked:${s.date}:${s.id}';

        try {
          await _notificationsPlugin.show(
            id: notifId,
            title: 'Unmarked: $subName (${s.date})',
            body: 'You haven\'t marked attendance for $subName (${s.startTime} - ${s.endTime}). Tap to open schedule!',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'class_attendance_channel',
                'Class Attendance Reminders',
                channelDescription: 'Reminders to mark attendance for scheduled classes',
                importance: Importance.high,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
                onlyAlertOnce: true,
                ongoing: false,
                autoCancel: true,
              ),
            ),
            payload: payload,
          );

          // Mark as notified once
          notifiedIds.add(s.id);
          await prefs.setStringList(notifiedKey, notifiedIds.toList());
        } catch (_) {}
      } else if (!isUnmarked) {
        // If the user marked it (present/absent), dismiss notification if still present
        await cancelUnmarkedNotification(s.id);
      }
    }
  }

  Future<void> cancelUnmarkedNotification(String sessionId) async {
    try {
      final notifId = _baseId(sessionId) + 2;
      await _notificationsPlugin.cancel(id: notifId);
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

      final androidDetails = AndroidNotificationDetails(
        'class_attendance_channel',
        'Class Attendance Reminders',
        channelDescription: 'Reminders to mark attendance for scheduled classes',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Class Reminder',
        playSound: true,
        enableVibration: true,
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
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDateTime,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'class_attendance_channel',
              'Class Attendance Reminders',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
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

  Future<void> cancelSessionReminder(String sessionId) async {
    try {
      final baseId = _baseId(sessionId);
      await _notificationsPlugin.cancel(id: baseId);
      await _notificationsPlugin.cancel(id: baseId + 1);
      await _notificationsPlugin.cancel(id: baseId + 2);
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
