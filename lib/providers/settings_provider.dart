import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../core/database/app_database.dart';
import '../core/models/user_settings.dart';
import '../core/services/haptic_service.dart';

class SettingsProvider with ChangeNotifier {
  UserSettings _settings = UserSettings();
  bool _isLoading = true;

  UserSettings get settings => _settings;
  bool get isLoading => _isLoading;

  ThemeMode get themeMode {
    switch (_settings.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    try {
      _settings = await AppDatabase.instance.getSettings();
      HapticService.enabled = _settings.hapticFeedbackEnabled;

      // Self-heal: If profile image exists in a temporary cache path, migrate it to documents directory
      if (_settings.profileImagePath != null) {
        final currentFile = File(_settings.profileImagePath!);
        if (await currentFile.exists()) {
          final appDir = await getApplicationDocumentsDirectory();
          if (!_settings.profileImagePath!.startsWith(appDir.path)) {
            final pathStr = _settings.profileImagePath!;
            final ext = pathStr.contains('.') ? pathStr.substring(pathStr.lastIndexOf('.')) : '.jpg';
            final newPath = '${appDir.path}/profile_avatar_${DateTime.now().millisecondsSinceEpoch}$ext';
            await currentFile.copy(newPath);
            await setProfileImage(newPath);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(UserSettings newSettings) async {
    _settings = newSettings;
    HapticService.enabled = newSettings.hapticFeedbackEnabled;
    notifyListeners();
    await AppDatabase.instance.updateSettings(newSettings);
  }

  Future<void> setHapticFeedback(bool enabled) async {
    await updateSettings(_settings.copyWith(hapticFeedbackEnabled: enabled));
  }

  Future<void> setThemeMode(String mode) async {
    await updateSettings(_settings.copyWith(themeMode: mode));
  }

  Future<void> setDefaultTarget(double target) async {
    await updateSettings(_settings.copyWith(defaultAttendanceTarget: target));
  }

  Future<void> updateStudentProfile({
    required String name,
    required String institution,
    required String course,
    required String semester,
  }) async {
    await updateSettings(_settings.copyWith(
      studentName: name,
      institutionName: institution,
      courseName: course,
      semester: semester,
    ));
  }

  Future<void> updateNotificationPreferences({
    required bool notificationsEnabled,
    required bool advanceReminderEnabled,
    required int advanceReminderMinutes,
  }) async {
    await updateSettings(_settings.copyWith(
      notificationsEnabled: notificationsEnabled,
      advanceReminderEnabled: advanceReminderEnabled,
      advanceReminderMinutes: advanceReminderMinutes,
    ));
  }

  Future<void> setProfileImage(String? path) async {
    if (path == null) {
      if (_settings.profileImagePath != null) {
        try {
          final oldFile = File(_settings.profileImagePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (_) {}
      }
      await updateSettings(_settings.copyWith(clearProfileImage: true));
    } else {
      String finalPath = path;
      try {
        final appDir = await getApplicationDocumentsDirectory();
        // If not already in the app's persistent documents directory, copy it there
        if (!path.startsWith(appDir.path)) {
          final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '.jpg';
          final savedFile = File('${appDir.path}/profile_avatar_${DateTime.now().millisecondsSinceEpoch}$ext');
          await File(path).copy(savedFile.path);
          finalPath = savedFile.path;

          // Clean up old persistent file
          if (_settings.profileImagePath != null && _settings.profileImagePath != finalPath) {
            final oldFile = File(_settings.profileImagePath!);
            if (await oldFile.exists()) {
              await oldFile.delete();
            }
          }
        }
      } catch (e) {
        debugPrint('Error saving persistent profile picture: $e');
      }
      await updateSettings(_settings.copyWith(profileImagePath: finalPath));
    }
  }

  Future<void> setSaturdayHolidayPattern(String pattern) async {
    await updateSettings(_settings.copyWith(saturdayHolidayPattern: pattern));
  }

  Future<void> addCustomHoliday(String ymd) async {
    final list = _settings.customHolidaysList;
    if (!list.contains(ymd)) {
      list.add(ymd);
      list.sort();
      await updateSettings(_settings.copyWith(customHolidays: list.join(',')));
    }
  }

  Future<void> removeCustomHoliday(String ymd) async {
    final list = _settings.customHolidaysList;
    list.remove(ymd);
    await updateSettings(_settings.copyWith(customHolidays: list.join(',')));
  }

  Future<void> setSemesterDateRange({String? startDate, String? endDate}) async {
    if (startDate == null || endDate == null) {
      await updateSettings(_settings.copyWith(clearSemesterRange: true));
    } else {
      await updateSettings(_settings.copyWith(
        semesterStartDate: startDate,
        semesterEndDate: endDate,
      ));
    }
  }
}

