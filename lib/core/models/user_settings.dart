class UserSettings {
  final String themeMode; // 'system', 'light', 'dark'
  final double defaultAttendanceTarget; // e.g. 75.0
  final String studentName;
  final String institutionName;
  final String courseName;
  final String semester;
  final bool notificationsEnabled;
  final bool advanceReminderEnabled;
  final int advanceReminderMinutes;
  final bool hapticFeedbackEnabled;
  final String? profileImagePath;
  final String saturdayHolidayPattern; // 'none', 'second_fourth', 'first_third', 'all_saturdays'
  final String customHolidays; // comma-separated 'YYYY-MM-DD,YYYY-MM-DD'
  final String? semesterStartDate; // 'YYYY-MM-DD' or null for full calendar
  final String? semesterEndDate; // 'YYYY-MM-DD' or null for full calendar

  UserSettings({
    this.themeMode = 'system',
    this.defaultAttendanceTarget = 75.0,
    this.studentName = '',
    this.institutionName = '',
    this.courseName = '',
    this.semester = '',
    this.notificationsEnabled = true,
    this.advanceReminderEnabled = false, // Off by default as requested
    this.advanceReminderMinutes = 5,    // Default 5 mins before class
    this.hapticFeedbackEnabled = true,
    this.profileImagePath,
    this.saturdayHolidayPattern = 'second_fourth',
    this.customHolidays = '',
    this.semesterStartDate,
    this.semesterEndDate,
  });

  bool get hasSemesterRange =>
      semesterStartDate != null &&
      semesterEndDate != null &&
      semesterStartDate!.trim().isNotEmpty &&
      semesterEndDate!.trim().isNotEmpty;

  DateTime? get semesterStartDateTime {
    if (semesterStartDate == null || semesterStartDate!.trim().isEmpty) return null;
    try {
      return DateTime.parse(semesterStartDate!.trim());
    } catch (_) {
      return null;
    }
  }

  DateTime? get semesterEndDateTime {
    if (semesterEndDate == null || semesterEndDate!.trim().isEmpty) return null;
    try {
      return DateTime.parse(semesterEndDate!.trim());
    } catch (_) {
      return null;
    }
  }

  bool isDateInSemester(DateTime date) {
    if (!hasSemesterRange) return true;
    final start = semesterStartDateTime;
    final end = semesterEndDateTime;
    if (start == null || end == null) return true;
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  List<String> get customHolidaysList {
    if (customHolidays.trim().isEmpty) return [];
    return customHolidays
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'theme_mode': themeMode,
      'default_attendance_target': defaultAttendanceTarget,
      'student_name': studentName,
      'institution_name': institutionName,
      'course_name': courseName,
      'semester': semester,
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'advance_reminder_enabled': advanceReminderEnabled ? 1 : 0,
      'advance_reminder_minutes': advanceReminderMinutes,
      'haptic_feedback_enabled': hapticFeedbackEnabled ? 1 : 0,
      'profile_image_path': profileImagePath,
      'saturday_holiday_pattern': saturdayHolidayPattern,
      'custom_holidays': customHolidays,
      'semester_start_date': semesterStartDate,
      'semester_end_date': semesterEndDate,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      themeMode: map['theme_mode'] as String? ?? 'system',
      defaultAttendanceTarget: (map['default_attendance_target'] as num?)?.toDouble() ?? 75.0,
      studentName: map['student_name'] as String? ?? '',
      institutionName: map['institution_name'] as String? ?? '',
      courseName: map['course_name'] as String? ?? '',
      semester: map['semester'] as String? ?? '',
      notificationsEnabled: (map['notifications_enabled'] as int?) != 0,
      advanceReminderEnabled: map['advance_reminder_enabled'] == null
          ? false
          : (map['advance_reminder_enabled'] as int?) == 1,
      advanceReminderMinutes: map['advance_reminder_minutes'] as int? ?? 5,
      hapticFeedbackEnabled: map['haptic_feedback_enabled'] == null
          ? true
          : (map['haptic_feedback_enabled'] as int?) == 1,
      profileImagePath: map['profile_image_path'] as String?,
      saturdayHolidayPattern: map['saturday_holiday_pattern'] as String? ?? 'second_fourth',
      customHolidays: map['custom_holidays'] as String? ?? '',
      semesterStartDate: map['semester_start_date'] as String?,
      semesterEndDate: map['semester_end_date'] as String?,
    );
  }

  UserSettings copyWith({
    String? themeMode,
    double? defaultAttendanceTarget,
    String? studentName,
    String? institutionName,
    String? courseName,
    String? semester,
    bool? notificationsEnabled,
    bool? advanceReminderEnabled,
    int? advanceReminderMinutes,
    bool? hapticFeedbackEnabled,
    String? profileImagePath,
    bool clearProfileImage = false,
    String? saturdayHolidayPattern,
    String? customHolidays,
    String? semesterStartDate,
    String? semesterEndDate,
    bool clearSemesterRange = false,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultAttendanceTarget: defaultAttendanceTarget ?? this.defaultAttendanceTarget,
      studentName: studentName ?? this.studentName,
      institutionName: institutionName ?? this.institutionName,
      courseName: courseName ?? this.courseName,
      semester: semester ?? this.semester,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      advanceReminderEnabled: advanceReminderEnabled ?? this.advanceReminderEnabled,
      advanceReminderMinutes: advanceReminderMinutes ?? this.advanceReminderMinutes,
      hapticFeedbackEnabled: hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      profileImagePath: clearProfileImage ? null : (profileImagePath ?? this.profileImagePath),
      saturdayHolidayPattern: saturdayHolidayPattern ?? this.saturdayHolidayPattern,
      customHolidays: customHolidays ?? this.customHolidays,
      semesterStartDate: clearSemesterRange ? null : (semesterStartDate ?? this.semesterStartDate),
      semesterEndDate: clearSemesterRange ? null : (semesterEndDate ?? this.semesterEndDate),
    );
  }
}
