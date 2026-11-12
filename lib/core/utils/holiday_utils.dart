import '../models/user_settings.dart';
import 'date_utils.dart';

class HolidayUtils {
  /// Check if a given date is considered a holiday based on user settings
  static bool isHoliday(DateTime date, UserSettings settings) {
    final ymd = AppDateUtils.formatDateYmd(date);

    // 1. Check custom declared holidays
    if (settings.customHolidaysList.contains(ymd)) {
      return true;
    }

    // 2. Check Sunday (traditional weekend off)
    if (date.weekday == DateTime.sunday) {
      return true;
    }

    // 3. Check Saturday pattern
    if (date.weekday == DateTime.saturday) {
      final nthSaturday = getNthSaturdayOfMonth(date);
      switch (settings.saturdayHolidayPattern) {
        case 'second_fourth':
          return nthSaturday == 2 || nthSaturday == 4;
        case 'first_third':
          return nthSaturday == 1 || nthSaturday == 3;
        case 'all_saturdays':
          return true;
        case 'none':
        default:
          return false;
      }
    }

    return false;
  }

  /// Returns a human-friendly description of why the day is off
  static String? getHolidayReason(DateTime date, UserSettings settings) {
    final ymd = AppDateUtils.formatDateYmd(date);
    if (settings.customHolidaysList.contains(ymd)) {
      return 'Declared Holiday';
    }

    if (date.weekday == DateTime.sunday) {
      return 'Sunday Off';
    }

    if (date.weekday == DateTime.saturday) {
      final nth = getNthSaturdayOfMonth(date);
      switch (settings.saturdayHolidayPattern) {
        case 'second_fourth':
          if (nth == 2) return '2nd Saturday Off';
          if (nth == 4) return '4th Saturday Off';
          break;
        case 'first_third':
          if (nth == 1) return '1st Saturday Off';
          if (nth == 3) return '3rd Saturday Off';
          break;
        case 'all_saturdays':
          return 'Saturday Off';
      }
    }

    return null;
  }

  /// Calculates which Saturday of the month this date is (1st, 2nd, 3rd, 4th, or 5th)
  static int getNthSaturdayOfMonth(DateTime date) {
    return ((date.day - 1) ~/ 7) + 1;
  }
}

