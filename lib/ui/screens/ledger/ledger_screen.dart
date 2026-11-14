import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/class_session.dart';
import '../../../core/models/subject.dart';
import '../../../core/models/user_settings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/attendance_calculator.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/nerdy_icons.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/paper_button.dart';
import '../../widgets/paper_card.dart';
import '../../widgets/paper_progress_bar.dart';
import '../../widgets/paper_stamp.dart';
import '../../widgets/staggered_entrance.dart';
import '../settings/csv_import_screen.dart';
import '../settings/settings_screen.dart';

class LedgerScreen extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;
  final bool isTabActive;
  const LedgerScreen({
    super.key,
    this.onSwitchTab,
    this.isTabActive = true,
  });

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  DateTime _scheduleDate = DateTime.now();
  late final PageController _heroPageController;
  int _activeHeroPage = 0;
  String? _selectedActiveSessionId;
  int _animTrigger = 0;

  @override
  void didUpdateWidget(covariant LedgerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      setState(() {
        _animTrigger++;
      });
    }
  }

  /// Returns true only when the semester end date has fully passed —
  /// i.e., either today is strictly after the end day, OR it IS the end day
  /// but all of today's sessions have already ended.
  bool _checkSemesterComplete(UserSettings settings, List<ClassSession> allSessions) {
    if (!settings.hasSemesterRange) return false;
    final now = DateTime.now();
    final endDt = settings.semesterEndDateTime!;
    final endDay = DateTime(endDt.year, endDt.month, endDt.day);
    final today = DateTime(now.year, now.month, now.day);

    if (today.isAfter(endDay)) return true;   // past the end day entirely
    if (today.isBefore(endDay)) return false; // end day hasn't come yet

    // It IS the end day — only mark complete after the last class ends
    final todayStr = AppDateUtils.formatDateYmd(now);
    final todaySessions = allSessions.where((s) => s.date == todayStr).toList();
    if (todaySessions.isEmpty) return true; // no classes scheduled today

    final lastEnd = todaySessions
        .map((s) => s.endDateTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return now.isAfter(lastEnd);
  }

  @override
  void initState() {
    super.initState();
    _heroPageController = PageController(initialPage: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final attendance = context.watch<AttendanceProvider>();
    if (!_isSameDay(_scheduleDate, attendance.selectedDate)) {
      _scheduleDate = attendance.selectedDate;
    }
  }

  @override
  void dispose() {
    _heroPageController.dispose();
    super.dispose();
  }

  void _previousDay() {
    HapticService.light();
    final newDate = _scheduleDate.subtract(const Duration(days: 1));
    setState(() {
      _scheduleDate = newDate;
    });
    context.read<AttendanceProvider>().setSelectedDate(newDate);
  }

  void _nextDay() {
    HapticService.light();
    final newDate = _scheduleDate.add(const Duration(days: 1));
    setState(() {
      _scheduleDate = newDate;
    });
    context.read<AttendanceProvider>().setSelectedDate(newDate);
  }

  void _resetToToday() {
    HapticService.selection();
    final now = DateTime.now();
    setState(() {
      _scheduleDate = now;
    });
    context.read<AttendanceProvider>().setSelectedDate(now);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getScheduleTitle(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return "Today's Schedule";
    if (_isSameDay(date, now.add(const Duration(days: 1)))) return "Tomorrow's Schedule";
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return "Yesterday's Schedule";
    return "${AppDateUtils.getWeekdayName(date.weekday)}'s Schedule";
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final settingsProv = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final target = settingsProv.settings.defaultAttendanceTarget;
    final settings = settingsProv.settings;
    final allSessions = attendance.allSessions;
    final isSemesterComplete = _checkSemesterComplete(settings, allSessions);

    final overallStats = attendance.overallStats;
    final subjects = attendance.subjects;
    final activeClasses = attendance.getActiveClasses(null, settings);
    final scheduleSessions = attendance.getSessionsForDate(_scheduleDate, settings);

    final subjectsMap = {for (var s in subjects) s.id: s};
    final profilePath = settingsProv.settings.profileImagePath;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (profilePath != null && File(profilePath).existsSync()) ...[
              Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.craftTeal, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                  image: DecorationImage(
                    image: FileImage(File(profilePath)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendance Ledger',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21),
                  ),
                  if (settingsProv.settings.studentName.isNotEmpty)
                    Text(
                      settingsProv.settings.institutionName.isNotEmpty
                          ? '${settingsProv.settings.studentName} • ${settingsProv.settings.institutionName}'
                          : settingsProv.settings.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282522) : const Color(0xFFEFE9DC),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    offset: const Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: const Icon(Icons.settings_outlined, size: 20),
            ),
            onPressed: () {
              HapticService.light();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => attendance.loadData(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100, top: 4),
          children: [
            // ── INTEGRATED HERO MODULE (ACTIVE CLASS + OVERALL ATTENDANCE) ──
            StaggeredEntrance(
              index: 0,
              child: _buildIntegratedHeroModule(
                activeClasses: activeClasses,
                subjectsMap: subjectsMap,
                overallStats: overallStats,
                target: target,
                attendance: attendance,
                settings: settingsProv.settings,
                isDark: isDark,
                allSessions: allSessions,
              ),
            ),

            const SizedBox(height: 12),

            // ── SCHEDULE SECTION WITH [<] [>] DAY NAVIGATION ──────────────
            StaggeredEntrance(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Row(
                children: [
                  const Icon(Icons.today_rounded, size: 20, color: AppColors.craftTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getScheduleTitle(_scheduleDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          AppDateUtils.formatDisplayDate(_scheduleDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Day Navigation Buttons [<] [>]
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF282522) : const Color(0xFFEFE9DC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          offset: const Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 22),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Previous day',
                          onPressed: _previousDay,
                        ),
                        Container(
                          width: 1,
                          height: 18,
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 22),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Next day',
                          onPressed: _nextDay,
                        ),
                      ],
                    ),
                  ),

                  if (!_isSameDay(_scheduleDate, DateTime.now())) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _resetToToday,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.craftTeal,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(35),
                              offset: const Offset(0, 2),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Schedule sessions or empty state
          if (scheduleSessions.isEmpty) ...[
            StaggeredEntrance(
              index: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: PaperCard(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  child: Column(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 42, color: AppColors.kraftBrown),
                      const SizedBox(height: 10),
                      Text(
                        'No classes scheduled for ${AppDateUtils.formatShortDate(_scheduleDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use the Timetable tab to schedule classes for this day.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            ...scheduleSessions.map((session) {
              final sub = subjectsMap[session.subjectId];
              final roomStr = (sub != null)
                  ? (sub.room != null && sub.room!.trim().isNotEmpty ? sub.room!.trim() : null)
                  : (session.room != null && session.room!.trim().isNotEmpty ? session.room!.trim() : null);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: PaperCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            if (roomStr != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.meeting_room_outlined,
                                    size: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      roomStr.toLowerCase().startsWith('room')
                                          ? roomStr
                                          : 'Room $roomStr',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (sub?.teacher != null && sub!.teacher!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      sub.teacher!.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    AppDateUtils.formatTimeRange(session.startTime, session.endTime),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                ),
              );
            }),
          ],

            // ── END OF SEMESTER TIMETABLE CREATION / SETUP CARD ─────────────
            if (isSemesterComplete) ...[
              const SizedBox(height: 12),
              _buildNewSemesterTimetableCard(context, isDark),
            ],
          ],
        ),
      ),
    );
  }

  // ── INTEGRATED HERO MODULE ────────────────────────────────────────────────
  Widget _buildIntegratedHeroModule({
    required List<ClassSession> activeClasses,
    required Map<String, Subject> subjectsMap,
    required OverallAttendanceStats overallStats,
    required double target,
    required AttendanceProvider attendance,
    required UserSettings settings,
    required bool isDark,
    required List<ClassSession> allSessions,
  }) {
    // If NO active class, display only the Overall Attendance Card (no scroll)
    if (activeClasses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          height: 302,
          child: _buildOverallAttendanceCard(
            overallStats: overallStats,
            target: target,
            settings: settings,
            isDark: isDark,
            allSessions: allSessions,
          ),
        ),
      );
    }

    // INSIDE ACTIVE CLASS TIME:
    // Horizontally scrollable PageView with Active Class card on Page 0 and
    // Overall Attendance on Page 1.
    final currentActiveSession = activeClasses.firstWhere(
      (s) => s.id == _selectedActiveSessionId,
      orElse: () => activeClasses.first,
    );

    return Column(
      children: [
        SizedBox(
          height: 318,
          child: PageView(
            controller: _heroPageController,
            onPageChanged: (idx) {
              setState(() => _activeHeroPage = idx);
              HapticService.selection();
            },
            children: [
              // Page 0: Active Class Present / Absent Marking Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildActiveClassCard(
                  session: currentActiveSession,
                  activeSessions: activeClasses,
                  subjectsMap: subjectsMap,
                  onMark: (status) async {
                    HapticService.heavy();
                    await attendance.markAttendance(currentActiveSession.id, status);

                    // Smoothly scroll to the Overall Attendance card on Page 1
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (mounted) {
                      _heroPageController.animateToPage(
                        1,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  },
                  isDark: isDark,
                ),
              ),

              // Page 1: Overall Attendance Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildOverallAttendanceCard(
                  overallStats: overallStats,
                  target: target,
                  settings: settings,
                  isDark: isDark,
                  allSessions: allSessions,
                ),
              ),
            ],
          ),
        ),

        // Page Indicator Dots
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPageDot(
                isActive: _activeHeroPage == 0,
                label: 'Active Class',
                icon: Icons.access_time_filled,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildPageDot(
                isActive: _activeHeroPage == 1,
                label: 'Overall Attendance',
                icon: Icons.pie_chart_rounded,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageDot({
    required bool isActive,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: isActive ? 10 : 6, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.craftTeal
            : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isActive
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          if (isActive) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── ACTIVE CLASS CARD (PAGE 0) ───────────────────────────────────────────
  Widget _buildActiveClassCard({
    required ClassSession session,
    required List<ClassSession> activeSessions,
    required Map<String, Subject> subjectsMap,
    required Future<void> Function(AttendanceStatus status) onMark,
    required bool isDark,
  }) {
    final subject = subjectsMap[session.subjectId];
    final activeRoomStr = (subject != null)
        ? (subject.room != null && subject.room!.trim().isNotEmpty ? subject.room!.trim() : null)
        : (session.room != null && session.room!.trim().isNotEmpty ? session.room!.trim() : null);
    final isAlreadyMarked = session.status != AttendanceStatus.unmarked;

    return PaperCard(
      showTape: true,
      tapeColor: AppColors.craftOrange,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      borderColor: AppColors.craftOrange.withAlpha(160),
      color: isDark ? const Color(0xFF2C251D) : const Color(0xFFFFF9F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.craftOrange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'CLASS IN SESSION NOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.craftOrange,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.craftOrange.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 11,
                      color: AppColors.craftOrange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppDateUtils.formatTimeRange(session.startTime, session.endTime),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.craftOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Multi-session selector if overlapping classes
          if (activeSessions.length > 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white60,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: activeSessions.map((s) {
                  final isSelected = s.id == session.id;
                  final sSub = subjectsMap[s.subjectId];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticService.selection();
                        setState(() => _selectedActiveSessionId = s.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.craftTeal : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sSub?.name ?? 'Subject',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Centered & Enlarged Hero Subject Section
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NerdySubjectBadge(
                    subjectName: subject?.name ?? 'Class',
                    subjectId: subject?.id,
                    colorValue: subject?.colorValue ?? 0xFFE65100,
                    size: 56,
                    iconSize: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subject?.name ?? 'Scheduled Class',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (activeRoomStr != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.meeting_room_outlined,
                              size: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activeRoomStr.toLowerCase().startsWith('room')
                                  ? activeRoomStr
                                  : 'Room $activeRoomStr',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      if (subject?.teacher != null && subject!.teacher!.trim().isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              subject.teacher!.trim(),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Buttons: Present / Absent
          if (isAlreadyMarked) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black38 : Colors.white70,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  PaperStampBadge(status: session.status, compact: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Marked. Swipe for stats →',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      final newStatus = session.status == AttendanceStatus.present
                          ? AttendanceStatus.absent
                          : AttendanceStatus.present;
                      onMark(newStatus);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        session.status == AttendanceStatus.present ? 'Switch Absent' : 'Switch Present',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.craftTeal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: AttendanceActionButton(
                    title: 'PRESENT',
                    color: AppColors.present,
                    icon: Icons.check_circle_rounded,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    iconSize: 28,
                    fontSize: 15,
                    onTap: () => onMark(AttendanceStatus.present),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AttendanceActionButton(
                    title: 'ABSENT',
                    color: AppColors.absent,
                    icon: Icons.cancel_rounded,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    iconSize: 28,
                    fontSize: 15,
                    onTap: () => onMark(AttendanceStatus.absent),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── OVERALL ATTENDANCE HERO CARD (PAGE 1) ─────────────────────────────────
  Widget _buildOverallAttendanceCard({
    required OverallAttendanceStats overallStats,
    required double target,
    required UserSettings settings,
    required bool isDark,
    required List<ClassSession> allSessions,
  }) {
    final isSemesterComplete = _checkSemesterComplete(settings, allSessions);

    final double pct = overallStats.percentage ?? 0.0;
    final bool extremelyLow = pct < 50.0 || (target >= 70 && pct < (target - 20));
    final bool belowTarget = !extremelyLow && pct < target;
    final bool onTheDot = pct >= target && pct <= (target + 3.0);

    final String roastTag;
    final Color roastColor;
    final String roastMessage;

    if (extremelyLow) {
      roastTag = '💀 COOKED BEYOND RECOGNITION FR FR';
      roastColor = AppColors.absent;
      roastMessage = 'Bro paid full tuition just to attend classes in spiritual form. The HOD has already framed your attendance sheet in the museum of modern horror. Finals are knocking on the door and your notes are 404 Not Found. Better start speedrunning the syllabus or pray for a divine server crash during exams 😭';
    } else if (belowTarget) {
      roastTag = '😭 ACADEMICALLY VULNERABLE';
      roastColor = AppColors.craftOrange;
      roastMessage = 'Bro thought the ${target.toInt()}% attendance target was just a gentle suggestion on Pinterest. Your exam hall ticket is currently hanging by a single dental floss thread. Go bake apology cookies for your professors or pull a 72-hour Red Bull study marathon before finals cook you completely 💀';
    } else if (onTheDot) {
      roastTag = '🗿 ACADEMIC EDGING CHAMPION';
      roastColor = AppColors.kraftGold;
      roastMessage = 'Bro calculated the minimum attendance down to the exact nanosecond. Cutting it closer than your phone battery hitting 1% with no charger in sight. Absolute risk taker behavior. Now channel that insane calculating skill into passing your exams!';
    } else {
      roastTag = '✨ PROFESSOR\'S CHOSEN CHILD';
      roastColor = AppColors.present;
      roastMessage = 'Who invited the front-row overachiever? Bro has never heard of the word "bunk" in their entire life. Gold star unlocked, now please go touch some grass 🌱. At least the exam invigilator actually knows your face. Go destroy those finals king!';
    }

    return PaperCard(
      showTape: true,
      tapeColor: AppColors.kraftGold,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: _buildOverallCardBody(
          overallStats: overallStats,
          target: target,
          isDark: isDark,
          isSemesterComplete: isSemesterComplete,
          roastTag: roastTag,
          roastColor: roastColor,
          roastMessage: roastMessage,
        ),
      ),
    );
  }

  Widget _buildOverallCardBody({
    required OverallAttendanceStats overallStats,
    required double target,
    required bool isDark,
    required bool isSemesterComplete,
    required String roastTag,
    required Color roastColor,
    required String roastMessage,
  }) {
    return Column(
      mainAxisAlignment: isSemesterComplete ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PaperCircularProgress(
              percentage: overallStats.percentage,
              targetPercentage: target,
              size: isSemesterComplete ? 116 : 138,
              strokeWidth: isSemesterComplete ? 10.5 : 12.0,
              animTrigger: _animTrigger,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'OVERALL ATTENDANCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${overallStats.totalPresent}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.present,
                        ),
                      ),
                      Text(
                        ' / ${overallStats.totalMarked}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'attended',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                  if (overallStats.totalMarked > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${overallStats.totalMarked} marked (${overallStats.totalPresent} Present, ${overallStats.totalAbsent} Absent)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _buildTargetStatusBadge(
                    overallStats: overallStats,
                    target: target,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),

        // IF SEMESTER COMPLETED: Show Congratulations & Gen-Z Exam Roasts!
        if (isSemesterComplete) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2C251D), const Color(0xFF382F24)]
                    : [const Color(0xFFFFF9ED), const Color(0xFFF9F1DF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.kraftGold, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.kraftGold.withAlpha(isDark ? 40 : 25),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('🎓', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CONGRATULATIONS ON COMPLETING THE SEMESTER!',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.kraftGold : const Color(0xFF916A00),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: roastColor.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: roastColor.withAlpha(120)),
                  ),
                  child: Text(
                    roastTag,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: roastColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  roastMessage,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          _buildAttendanceInsightBanner(
            overallStats: overallStats,
            target: target,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  // ── NEW SEMESTER TIMETABLE CREATION / SETUP CARD ───────────────────────────
  Widget _buildNewSemesterTimetableCard(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: PaperCard(
        showTape: true,
        tapeColor: AppColors.craftTeal,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school_rounded, color: AppColors.craftTeal, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'START NEW SEMESTER TIMETABLE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: isDark ? AppColors.craftTeal : const Color(0xFF1E5958),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your current semester has officially ended! Set up your schedule for the next term using one of these options:',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 14),

            // Option 1: Import CSV
            _buildTimetableOptionTile(
              icon: Icons.upload_file_rounded,
              color: AppColors.craftTeal,
              title: 'Import Timetable via CSV',
              subtitle: 'Upload a class timetable CSV with subjects, timings & rooms',
              onTap: () {
                HapticService.selection();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CsvImportScreen()),
                );
              },
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            // Option 2: Go to Timetable Tab
            _buildTimetableOptionTile(
              icon: Icons.calendar_month_rounded,
              color: AppColors.kraftGold,
              title: 'Go to Timetable Tab',
              subtitle: 'Set new semester term dates & manually schedule classes',
              onTap: () {
                HapticService.selection();
                widget.onSwitchTab?.call(1);
              },
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            // Option 3: Go to Subjects Tab
            _buildTimetableOptionTile(
              icon: Icons.menu_book_rounded,
              color: AppColors.craftPlum,
              title: 'Go to Subjects Tab',
              subtitle: 'Add new courses, subject codes, faculty & targets',
              onTap: () {
                HapticService.selection();
                widget.onSwitchTab?.call(2);
              },
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 25 : 18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(100), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 50 : 35),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceInsightBanner({
    required OverallAttendanceStats overallStats,
    required double target,
    required bool isDark,
  }) {
    if (overallStats.percentage == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.kraftGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mark attendance to unlock target projections and safe-miss estimates.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final meets = overallStats.meetsTarget(target);
    final needed = AttendanceCalculator.classesNeededToReachTarget(overallStats, target);
    final canMiss = AttendanceCalculator.classesCanSafelyMiss(overallStats, target);

    final String message;
    final IconData icon;
    final Color badgeColor;

    if (meets) {
      badgeColor = AppColors.present;
      icon = Icons.verified_rounded;
      if (canMiss > 0) {
        message = 'You can safely miss $canMiss upcoming class${canMiss == 1 ? "" : "es"} and still stay above ${target.toInt()}%.';
      } else {
        message = 'You are right at your target! Don\'t miss the next class to maintain ${target.toInt()}%.';
      }
    } else {
      badgeColor = AppColors.absent;
      icon = Icons.warning_amber_rounded;
      message = 'Attend the next $needed consecutive class${needed == 1 ? "" : "es"} to hit your ${target.toInt()}% target.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(isDark ? 28 : 18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withAlpha(90), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(14),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: badgeColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Target: ${target.toInt()}%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(isDark ? 45 : 25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withAlpha(90)),
                ),
                child: Text(
                  meets
                      ? (canMiss > 0 ? '🛡️ Safe to miss: $canMiss' : '🎯 On the mark')
                      : '🚨 Need $needed in a row',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetStatusBadge({
    required OverallAttendanceStats overallStats,
    required double target,
    required bool isDark,
  }) {
    if (overallStats.percentage == null) {
      return Text(
        'No attendance recorded yet',
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      );
    }

    final meets = overallStats.meetsTarget(target);
    final color = meets ? AppColors.present : AppColors.absent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(120)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            offset: const Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meets ? Icons.check_circle : Icons.error_outline, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            meets ? 'On Track' : 'Below Target',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
