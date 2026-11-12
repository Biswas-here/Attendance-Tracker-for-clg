import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat _ymdFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('EEE, MMM d, yyyy');
  static final DateFormat _shortDateFormat = DateFormat('MMM d');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat _timeFormat12 = DateFormat('h:mm a');

  static String formatDateYmd(DateTime date) => _ymdFormat.format(date);
  static String formatDisplayDate(DateTime date) => _displayDateFormat.format(date);
  static String formatShortDate(DateTime date) => _shortDateFormat.format(date);
  static String formatMonthYear(DateTime date) => _monthYearFormat.format(date);

  static DateTime parseYmd(String ymd) => _ymdFormat.parse(ymd);

  static String formatTime12(String hhmm) {
    try {
      final parts = hhmm.split(':');
      final dt = DateTime(2026, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return _timeFormat12.format(dt);
    } catch (_) {
      return hhmm;
    }
  }

  static String formatTimeRange(String startHhmm, String endHhmm) {
    return '${formatTime12(startHhmm)} - ${formatTime12(endHhmm)}';
  }

  static String getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  static String getWeekdayShort(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}

