import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/notification_service.dart';
import '../../providers/attendance_provider.dart';
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

    // Initial notification housekeeping in background microtask after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncNotificationsInBackground();
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
      // Clear fired/active reminders, preserving unmarked class notifications
      await NotificationService.instance.clearActiveFiredReminders(
        allSessions: attendance.allSessions,
      );

      // Sync past unmarked class notifications
      final subjectNames = {for (var s in attendance.subjects) s.id: s.name};
      await NotificationService.instance.syncUnmarkedClassNotifications(
        allSessions: attendance.allSessions,
        subjectNames: subjectNames,
      );
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
        onSwitchTab: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      const TimetableScreen(),
      const SubjectsScreen(),
      const AnalyticsScreen(),
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

