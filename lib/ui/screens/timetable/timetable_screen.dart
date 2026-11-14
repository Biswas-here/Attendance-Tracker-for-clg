import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/holiday_utils.dart';
import '../../../core/utils/nerdy_icons.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/paper_card.dart';
import '../../widgets/paper_stamp.dart';
import '../../widgets/staggered_entrance.dart';
import 'schedule_class_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _goToToday(AttendanceProvider attendance) {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
    });
    attendance.setSelectedDate(now);
  }

  void _showSemesterRangePicker(BuildContext context, SettingsProvider settingsProv) {
    final settings = settingsProv.settings;
    DateTime? startDate = settings.semesterStartDateTime ?? DateTime.now();
    DateTime? endDate = settings.semesterEndDateTime ?? DateTime.now().add(const Duration(days: 120));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final sheetBg = isDark ? const Color(0xFF262320) : const Color(0xFFF9F5EC);

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.date_range_rounded, color: AppColors.craftTeal, size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'Semester Term Bounds',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Set the start and end dates of your academic semester. Classes will only show and run between these dates. Clear them to let your timetable span throughout the entire calendar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Semester', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setSheetState(() => startDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: AppColors.craftTeal),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      startDate != null ? AppDateUtils.formatShortDate(startDate!) : 'Select Date',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Semester', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate ?? (startDate?.add(const Duration(days: 90)) ?? DateTime.now()),
                                firstDate: startDate ?? DateTime(2024),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setSheetState(() => endDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_busy, size: 16, color: AppColors.craftOrange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      endDate != null ? AppDateUtils.formatShortDate(endDate!) : 'Select Date',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (settings.hasSemesterRange) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: AppColors.absent),
                            foregroundColor: AppColors.absent,
                          ),
                          onPressed: () async {
                            await settingsProv.setSemesterDateRange(startDate: null, endDate: null);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.all_inclusive_rounded, size: 18),
                          label: const Text('Clear Bounds', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.craftTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (startDate != null && endDate != null) {
                            if (endDate!.isBefore(startDate!)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('End semester date must be after start semester date.')),
                              );
                              return;
                            }
                            final sStr = AppDateUtils.formatDateYmd(startDate!);
                            final eStr = AppDateUtils.formatDateYmd(endDate!);
                            final attendanceProv = context.read<AttendanceProvider>();
                            await settingsProv.setSemesterDateRange(startDate: sStr, endDate: eStr);
                            final result = await attendanceProv.syncSessionsForSemester(
                              startDate: startDate!,
                              endDate: endDate!,
                              userSettings: settingsProv.settings,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              final String msg;
                              if (result.added > 0 && result.removed > 0) {
                                msg = 'Semester updated: +${result.added} classes added, ${result.removed} pruned.';
                              } else if (result.added > 0) {
                                msg = 'Semester extended: +${result.added} classes scheduled up to ${AppDateUtils.formatShortDate(endDate!)}.';
                              } else if (result.removed > 0) {
                                msg = 'Semester trimmed: ${result.removed} classes outside range pruned.';
                              } else {
                                msg = 'Semester term updated successfully!';
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Save Term', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQuickAddDialog(DateTime date) {
    final attendance = context.read<AttendanceProvider>();
    final settings = context.read<SettingsProvider>().settings;
    final subjects = attendance.subjects;

    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a subject first!')),
      );
      return;
    }

    String selectedSubjectId = subjects.first.id;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Quick Add Class for ${AppDateUtils.formatShortDate(date)}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Subject:', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedSubjectId,
                  items: subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedSubjectId = val);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(startTime.format(context)),
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: startTime);
                          if (picked != null) setDialogState(() => startTime = picked);
                        },
                      ),
                    ),
                    const Text('to'),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(endTime.format(context)),
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: endTime);
                          if (picked != null) setDialogState(() => endTime = picked);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.craftTeal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                  final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

                  await attendance.addSingleSession(
                    subjectId: selectedSubjectId,
                    date: date,
                    startTime: startStr,
                    endTime: endStr,
                    userSettings: settings,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final settingsProv = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDate = attendance.selectedDate;
    final subjectsMap = {for (var s in attendance.subjects) s.id: s};
    final daySessions = attendance.getSessionsForDate(selectedDate, settingsProv.settings);
    final holidayReason = HolidayUtils.getHolidayReason(selectedDate, settingsProv.settings);
    final isInSemester = settingsProv.settings.isDateInSemester(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable & Calendar', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScheduleClassScreen(initialDate: selectedDate),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.craftTeal,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(45),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 17, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Schedule',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ── SEMESTER TERM CONFIGURATION BAR ─────────────────────────────
          StaggeredEntrance(
            index: 0,
            child: _buildSemesterTermBar(settingsProv, settingsProv.settings, isDark),
          ),

          // ── MODERN DIGITAL PLANNER CALENDAR CARD ────────────────────────
          StaggeredEntrance(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: PaperCard(
              showTape: true,
              tapeColor: AppColors.craftTeal,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              child: Column(
                children: [
                  // Month navigation row with "Today" quick button
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 24),
                        onPressed: _previousMonth,
                        tooltip: 'Previous month',
                      ),
                      Expanded(
                        child: Text(
                          AppDateUtils.formatMonthYear(_currentMonth),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 24),
                        onPressed: _nextMonth,
                        tooltip: 'Next month',
                      ),
                      TextButton(
                        onPressed: () => _goToToday(attendance),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(
                            color: AppColors.craftTeal,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Weekday headers (7 columns)
                  Row(
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                      final isWeekend = day == 'Sat' || day == 'Sun';
                      return Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isWeekend
                                  ? AppColors.kraftBrown
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Calendar Days Grid with smooth animated transitions
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: _buildMonthGrid(
                      key: ValueKey(_currentMonth),
                      month: _currentMonth,
                      selectedDate: selectedDate,
                      attendance: attendance,
                      settings: settingsProv.settings,
                      isDark: isDark,
                    ),
                  ),

                  const SizedBox(height: 14),
                  // Attendance legend
                  _buildCalendarLegend(isDark),
                ],
              ),
            ),
          ),
        ),

          // ── HOLIDAY BANNER IF SELECTED DATE IS HOLIDAY ─────────────────
          if (holidayReason != null && isInSemester)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.kraftGold.withAlpha(isDark ? 35 : 22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.kraftGold.withAlpha(120)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.beach_access_rounded, color: AppColors.kraftGold, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            holidayReason,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          Text(
                            'Scheduled off-day based on your holiday settings.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── OUTSIDE SEMESTER TERM BANNER ────────────────────────────────
          if (settingsProv.settings.hasSemesterRange && !isInSemester)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF28231E) : const Color(0xFFF7F1E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_busy_rounded, color: AppColors.craftOrange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Outside Semester Term',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Active semester: ${AppDateUtils.formatShortDate(settingsProv.settings.semesterStartDateTime!)} to ${AppDateUtils.formatShortDate(settingsProv.settings.semesterEndDateTime!)}. Classes only run during those days.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── SELECTED DATE SCHEDULE HEADER ───────────────────────────────
          StaggeredEntrance(
            index: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppDateUtils.formatDisplayDate(selectedDate),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${daySessions.length} Class${daySessions.length == 1 ? "" : "es"} Scheduled',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF2C2825) : const Color(0xFFEBE6DC),
                      foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
                        ),
                      ),
                    ),
                    onPressed: () => _showQuickAddDialog(selectedDate),
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Quick Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),

          // ── SESSIONS LIST OR EMPTY STATE ────────────────────────────────
          if (daySessions.isEmpty)
            StaggeredEntrance(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: PaperCard(
                  child: Column(
                    children: [
                      const Icon(Icons.event_available, size: 44, color: AppColors.kraftBrown),
                      const SizedBox(height: 10),
                      const Text(
                        'No classes scheduled for this date',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        holidayReason != null
                            ? 'This date is marked as an off-day ($holidayReason).'
                            : 'Tap Quick Add or Schedule above to add a class.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...daySessions.map((session) {
              final sub = subjectsMap[session.subjectId];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: PaperCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          NerdySubjectBadge(
                            subjectName: sub?.name ?? 'Class',
                            subjectId: sub?.id,
                            colorValue: sub?.colorValue ?? 0xFF3F7E7D,
                            size: 38,
                            iconSize: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sub?.name ?? 'Scheduled Class',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                                if (sub?.teacher != null && sub!.teacher!.isNotEmpty)
                                  Text(
                                    sub.teacher!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Scheduled Class?'),
                                  content: const Text('This will remove this class occurrence.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete', style: TextStyle(color: AppColors.absent)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                attendance.deleteSession(session.id);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_filled,
                                  size: 13,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppDateUtils.formatTimeRange(session.startTime, session.endTime),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          PaperStampBadge(status: session.status, compact: true),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mark Attendance:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          QuickAttendanceStamps(
                            currentStatus: session.status,
                            onStatusChanged: (newStatus) {
                              attendance.markAttendance(session.id, newStatus);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── 7-COLUMN MONTH GRID ──────────────────────────────────────────────────
  Widget _buildMonthGrid({
    required Key key,
    required DateTime month,
    required DateTime selectedDate,
    required AttendanceProvider attendance,
    required dynamic settings,
    required bool isDark,
  }) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // 1 = Mon, 7 = Sun
    final today = DateTime.now();

    final List<Widget?> cells = [];

    // Leading blanks
    for (int i = 1; i < firstWeekday; i++) {
      cells.add(null);
    }
    // Days
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(_buildDateCell(
        day: d,
        month: month,
        selectedDate: selectedDate,
        today: today,
        attendance: attendance,
        settings: settings,
        isDark: isDark,
      ));
    }
    // Trailing blanks to complete the final week row
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final List<Widget> rows = [];
    for (int i = 0; i < cells.length; i += 7) {
      final weekCells = cells.sublist(i, i + 7);
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: weekCells.map((c) => Expanded(child: c ?? const SizedBox(height: 44))).toList(),
          ),
        ),
      );
    }

    return Column(key: key, children: rows);
  }

  Widget _buildDateCell({
    required int day,
    required DateTime month,
    required DateTime selectedDate,
    required DateTime today,
    required AttendanceProvider attendance,
    required dynamic settings,
    required bool isDark,
  }) {
    final cellDate = DateTime(month.year, month.month, day);
    final isSelected = cellDate.year == selectedDate.year &&
        cellDate.month == selectedDate.month &&
        cellDate.day == selectedDate.day;
    final isToday = cellDate.year == today.year &&
        cellDate.month == today.month &&
        cellDate.day == today.day;

    final isInSemester = settings.isDateInSemester(cellDate);
    final status = attendance.getDateStatus(cellDate, settings);
    final isHoliday = isInSemester && HolidayUtils.isHoliday(cellDate, settings);

    return GestureDetector(
      onTap: () => attendance.setSelectedDate(cellDate),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.craftTeal
              : (!isInSemester
                  ? Colors.transparent
                  : (isToday
                      ? (isDark ? const Color(0xFF2A2825) : const Color(0xFFEBE5D8))
                      : (isHoliday
                          ? (isDark ? Colors.black26 : const Color(0xFFF3ECE0))
                          : Colors.transparent))),
          borderRadius: BorderRadius.circular(10),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.craftTeal, width: 1.5)
              : (isSelected
                  ? Border.all(color: AppColors.craftTeal, width: 1.5)
                  : (isHoliday && !isSelected
                      ? Border.all(color: AppColors.kraftGold.withAlpha(70), width: 1)
                      : (!isInSemester && !isSelected
                          ? Border.all(color: (isDark ? Colors.white : Colors.black).withAlpha(12), width: 0.8)
                          : null))),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (!isInSemester
                        ? (isDark ? Colors.white30 : Colors.black26)
                        : (isHoliday
                            ? AppColors.kraftBrown
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
              ),
            ),
            const SizedBox(height: 3),
            _buildStatusIndicator(status, isSelected, isHoliday),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status, bool isSelected, bool isHoliday) {
    if (status == 'none' && isHoliday) {
      return Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white70 : AppColors.kraftGold,
          shape: BoxShape.circle,
        ),
      );
    }

    Color dotColor;
    switch (status) {
      case 'green':
        dotColor = isSelected ? Colors.white : AppColors.present;
        break;
      case 'red':
        dotColor = isSelected ? const Color(0xFFFF8A80) : AppColors.absent;
        break;
      case 'partial':
        dotColor = isSelected ? const Color(0xFFFFD54F) : AppColors.kraftGold;
        break;
      case 'unmarked':
        dotColor = isSelected ? Colors.white60 : AppColors.unmarked;
        break;
      case 'future':
        dotColor = isSelected ? Colors.white54 : AppColors.craftTeal.withAlpha(140);
        break;
      default:
        return const SizedBox(height: 5);
    }

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCalendarLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendItem(AppColors.present, 'Attended'),
          _legendItem(AppColors.absent, 'Missed'),
          _legendItem(AppColors.kraftGold, 'Partial'),
          _legendItem(AppColors.unmarked, 'Unmarked'),
          _legendItem(AppColors.kraftGold.withAlpha(160), 'Holiday'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildSemesterTermBar(SettingsProvider settingsProv, dynamic settings, bool isDark) {
    final hasRange = settings.hasSemesterRange as bool;
    final start = settings.semesterStartDateTime as DateTime?;
    final end = settings.semesterEndDateTime as DateTime?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: PaperCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: (hasRange ? AppColors.craftTeal : AppColors.kraftGold).withAlpha(isDark ? 45 : 25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hasRange ? Icons.date_range_rounded : Icons.all_inclusive_rounded,
                color: hasRange ? AppColors.craftTeal : AppColors.kraftBrown,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'SEMESTER TERM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: (hasRange ? AppColors.present : AppColors.craftTeal).withAlpha(isDark ? 40 : 20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          hasRange ? 'Active Bounds' : 'Full Calendar',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: hasRange ? AppColors.present : AppColors.craftTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasRange && start != null && end != null
                        ? '${AppDateUtils.formatShortDate(start)}  →  ${AppDateUtils.formatShortDate(end)}'
                        : 'No semester bounds set (All days active)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showSemesterRangePicker(context, settingsProv),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2723) : const Color(0xFFEBE5D8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasRange ? Icons.edit_calendar_rounded : Icons.add_rounded,
                      size: 14,
                      color: AppColors.craftTeal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasRange ? 'Change' : 'Set Term',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.craftTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
