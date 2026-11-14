import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/notification_service.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/floating_nav_dock.dart';
import 'analytics/analytics_screen.dart';
import 'ledger/ledger_screen.dart';
import 'subjects/subjects_screen.dart';
import 'timetable/timetable_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to notification payload events (e.g. tapping an unmarked class notification)
    NotificationService.onNotificationPayload.addListener(_handleNotificationPayload);

    // Initial notification housekeeping deferred to ensure butter-smooth 120Hz/60Hz launch scrolling
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _syncNotificationsInBackground();
      }
    });
  }

  @override
  void dispose() {
    NotificationService.onNotificationPayload.removeListener(_handleNotificationPayload);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _syncNotificationsInBackground() async {
    if (!mounted) return;
    try {
      final attendance = context.read<AttendanceProvider>();
      final settingsProv = context.read<SettingsProvider>();
      final settings = settingsProv.settings;

      // If semester has ended, cancel all class notifications and do not schedule any
      if (settings.isSemesterEnded) {
        await NotificationService.instance.cancelAll();
        return;
      }

      // Dismiss already-started active reminders from panel, preserving upcoming alarms & end-of-class unmarked alarms
      await NotificationService.instance.clearActiveFiredReminders(
        allSessions: attendance.allSessions,
      );

      // Sync past unmarked class notifications
      final subjectNames = {for (var s in attendance.subjects) s.id: s.name};
      await NotificationService.instance.syncUnmarkedClassNotifications(
        allSessions: attendance.allSessions,
        subjectNames: subjectNames,
        settings: settings,
      );

      // Ensure upcoming 14 days of classes are scheduled in AlarmManager
      await attendance.syncAllUpcomingNotifications(settings);
    } catch (e) {
      debugPrint('Background notification sync error: $e');
    }
  }

  Future<void> _onAppResumed() async {
    if (!mounted) return;
    final attendance = context.read<AttendanceProvider>();
    await attendance.loadData(showLoading: false);
    await _syncNotificationsInBackground();
  }

  void _handleNotificationPayload() {
    final payload = NotificationService.onNotificationPayload.value;
    if (payload == null || !mounted) return;

    if (payload.startsWith('unmarked:')) {
      final parts = payload.split(':');
      if (parts.length >= 2) {
        final dateStr = parts[1];
        final parsedDate = DateTime.tryParse(dateStr);
        if (parsedDate != null) {
          // Switch to Ledger tab and navigate to that specific day
          setState(() => _currentIndex = 0);
          context.read<AttendanceProvider>().setSelectedDate(parsedDate);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      LedgerScreen(
        isTabActive: _currentIndex == 0,
        onSwitchTab: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      const TimetableScreen(),
      const SubjectsScreen(),
      AnalyticsScreen(
        isTabActive: _currentIndex == 3,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: FloatingNavDock(
        currentIndex: _currentIndex,
        onIndexChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

