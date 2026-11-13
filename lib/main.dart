import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/attendance_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsProvider = SettingsProvider();
  final attendanceProvider = AttendanceProvider();

  // Initialize notification service and pre-load settings & attendance data
  // BEFORE first frame is rendered to guarantee seamless, zero-flicker theme on startup.
  await Future.wait([
    NotificationService.instance.init(
      onNotificationTapped: (payload) {
        NotificationService.onNotificationPayload.value = payload;
      },
    ),
    settingsProvider.loadSettings(),
    attendanceProvider.loadData(),
  ]);

  // Sync upcoming notifications in AlarmManager
  await attendanceProvider.syncAllUpcomingNotifications(settingsProvider.settings);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<AttendanceProvider>.value(value: attendanceProvider),
      ],
      child: const AttendanceApp(),
    ),
  );
}

class SmoothScrollBehavior extends MaterialScrollBehavior {
  const SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Attendance Tracker',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const SmoothScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsProv.themeMode,
      home: const MainNavigationScreen(),
    );
  }
}
