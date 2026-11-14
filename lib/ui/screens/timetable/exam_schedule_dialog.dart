import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/nerdy_icons.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/settings_provider.dart';

enum ExamScheduleType {
  fullDay, // Exam then holiday (no regular classes)
  halfDay, // Exam during specific hours (classes before/after)
}

class ExamEntryItem {
  DateTime date;
  String subjectId;
  String subjectName;
  int colorValue;
  String room;

  ExamEntryItem({
    required this.date,
    required this.subjectId,
    required this.subjectName,
    required this.colorValue,
    this.room = 'Exam Hall',
  });
}

class ExamScheduleDialog extends StatefulWidget {
  final DateTime initialDate;

  const ExamScheduleDialog({
    super.key,
    required this.initialDate,
  });

  @override
  State<ExamScheduleDialog> createState() => _ExamScheduleDialogState();
}

class _ExamScheduleDialogState extends State<ExamScheduleDialog> {
  ExamScheduleType _scheduleType = ExamScheduleType.fullDay;

  // Timings for half-day exam
  TimeOfDay _halfDayStartTime = const TimeOfDay(hour: 9, minute: 30);
  TimeOfDay _halfDayEndTime = const TimeOfDay(hour: 12, minute: 30);

  // List of exams added
  final List<ExamEntryItem> _examList = [];

  // Toggles
  bool _excludeGapDays = true;
  bool _createExamSessions = true;

  // Form state for adding an exam
  late DateTime _newExamDate;
  String? _selectedSubjectId;
  final TextEditingController _roomController = TextEditingController(text: 'Exam Hall');

  @override
  void initState() {
    super.initState();
    _newExamDate = widget.initialDate;
    final subjects = context.read<AttendanceProvider>().subjects;
    if (subjects.isNotEmpty) {
      _selectedSubjectId = subjects.first.id;
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  void _addCurrentExam() {
    if (_selectedSubjectId == null) return;
    final subjects = context.read<AttendanceProvider>().subjects;
    final sub = subjects.firstWhere(
      (s) => s.id == _selectedSubjectId,
      orElse: () => subjects.first,
    );

    final ymd = AppDateUtils.formatDateYmd(_newExamDate);
    // Avoid duplicate exams on same date for same subject
    final exists = _examList.any(
      (e) => AppDateUtils.formatDateYmd(e.date) == ymd && e.subjectId == sub.id,
    );
    if (exists) return;

    setState(() {
      _examList.add(ExamEntryItem(
        date: _newExamDate,
        subjectId: sub.id,
        subjectName: sub.name,
        colorValue: sub.colorValue,
        room: _roomController.text.trim().isNotEmpty ? _roomController.text.trim() : 'Exam Hall',
      ));
      // Sort exams chronologically
      _examList.sort((a, b) => a.date.compareTo(b.date));
      // Automatically advance default new date to next day
      _newExamDate = _newExamDate.add(const Duration(days: 2));
    });
    HapticService.selection();
  }

  int _calculateGapDaysCount() {
    if (_examList.length < 2) return 0;
    final dates = _examList.map((e) => e.date).toList()..sort();
    final first = dates.first;
    final last = dates.last;
    final examDateStrs = _examList.map((e) => AppDateUtils.formatDateYmd(e.date)).toSet();

    int count = 0;
    var cur = first.add(const Duration(days: 1));
    while (cur.isBefore(last)) {
      final ymd = AppDateUtils.formatDateYmd(cur);
      if (!examDateStrs.contains(ymd)) {
        count++;
      }
      cur = cur.add(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _pickHalfDayTime(bool isStart) async {
    final initial = isStart ? _halfDayStartTime : _halfDayEndTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _halfDayStartTime = picked;
        } else {
          _halfDayEndTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _applySchedule() async {
    if (_examList.isEmpty) return;

    final attendance = context.read<AttendanceProvider>();
    final settingsProv = context.read<SettingsProvider>();

    final examsData = _examList.map((e) => {
      'date': AppDateUtils.formatDateYmd(e.date),
      'subjectId': e.subjectId,
      'subjectName': e.subjectName,
      'room': e.room,
    }).toList();

    final result = await attendance.applyExamSchedule(
      isHalfDay: _scheduleType == ExamScheduleType.halfDay,
      examStartTime: _scheduleType == ExamScheduleType.halfDay ? _formatTime(_halfDayStartTime) : null,
      examEndTime: _scheduleType == ExamScheduleType.halfDay ? _formatTime(_halfDayEndTime) : null,
      exams: examsData,
      excludeGapDays: _excludeGapDays,
      createExamSessions: _createExamSessions,
      settings: settingsProv.settings,
      onHolidaysAdded: (gapHolidays) async {
        for (final ymd in gapHolidays) {
          await settingsProv.addCustomHoliday(ymd);
        }
      },
    );

    if (mounted) {
      Navigator.pop(context);
      final removed = result['removed'] ?? 0;
      final examsCount = _examList.length;
      final gaps = result['gaps'] ?? 0;

      String msg = 'Exam schedule applied! $examsCount exam(s) scheduled.';
      if (gaps > 0) {
        msg += ' $gaps study gap day(s) marked as holidays.';
      }
      if (removed > 0) {
        msg += ' $removed conflicting class(es) removed from attendance.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attendance = context.watch<AttendanceProvider>();
    final subjects = attendance.subjects;
    final gapCount = _calculateGapDaysCount();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF262421) : const Color(0xFFFAF7F0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── HEADER ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.craftTeal.withAlpha(isDark ? 45 : 30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded, color: AppColors.craftTeal, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exam & Holiday Planner',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                        Text(
                          'Schedule exams and handle class holidays',
                          style: TextStyle(fontSize: 11, color: AppColors.craftTeal, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── SCROLLABLE BODY ──────────────────────────────────────
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                children: [
                  // 1. Choose Holiday / Exam Type
                  const Text(
                    '1. Choose Exam Schedule Type',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // Full-day exam (Holiday after exam)
                      Expanded(
                        child: _typeSelectionCard(
                          title: 'Full Day / Exam Then Holiday',
                          subtitle: 'No regular classes',
                          icon: Icons.beach_access_rounded,
                          isSelected: _scheduleType == ExamScheduleType.fullDay,
                          onTap: () {
                            setState(() => _scheduleType = ExamScheduleType.fullDay);
                            HapticService.selection();
                          },
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Half-day exam
                      Expanded(
                        child: _typeSelectionCard(
                          title: 'Half-Day Exam',
                          subtitle: 'Classes before/after',
                          icon: Icons.access_time_filled_rounded,
                          isSelected: _scheduleType == ExamScheduleType.halfDay,
                          onTap: () {
                            setState(() => _scheduleType = ExamScheduleType.halfDay);
                            HapticService.selection();
                          },
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  // Half-day timings (Only requested if Half-Day exam!)
                  if (_scheduleType == ExamScheduleType.halfDay) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2825) : const Color(0xFFF2ECE1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 16, color: AppColors.craftTeal),
                              SizedBox(width: 6),
                              Text(
                                'Exam Hours (Classes during this time are cancelled)',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _pickHalfDayTime(true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF201D1A) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Start:', style: TextStyle(fontSize: 12)),
                                        Text(
                                          _formatTime(_halfDayStartTime),
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _pickHalfDayTime(false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF201D1A) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('End:', style: TextStyle(fontSize: 12)),
                                        Text(
                                          _formatTime(_halfDayEndTime),
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // 2. Add Exam Dates & Subject Labels
                  const Text(
                    '2. Add Exam Dates & Subject Labels',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  // Date picker & Subject picker row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2825) : const Color(0xFFF2ECE1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Date picker button
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _newExamDate,
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() => _newExamDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF201D1A) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.craftTeal),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          AppDateUtils.formatShortDate(_newExamDate),
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Subject dropdown
                            Expanded(
                              flex: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF201D1A) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: subjects.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Text('No subjects added', style: TextStyle(fontSize: 12)),
                                      )
                                    : DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedSubjectId,
                                          isExpanded: true,
                                          items: subjects.map((s) {
                                            return DropdownMenuItem<String>(
                                              value: s.id,
                                              child: Text(
                                                s.name,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) setState(() => _selectedSubjectId = val);
                                          },
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.craftTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: subjects.isNotEmpty ? _addCurrentExam : null,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add This Exam', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Added Exams List
                  if (_examList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${_examList.length} Exam${_examList.length == 1 ? "" : "s"} Scheduled:',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.craftTeal),
                    ),
                    const SizedBox(height: 6),
                    ..._examList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final exam = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2825) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            NerdySubjectBadge(
                              subjectName: exam.subjectName,
                              subjectId: exam.subjectId,
                              colorValue: exam.colorValue,
                              size: 26,
                              iconSize: 15,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exam.subjectName,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    AppDateUtils.formatShortDate(exam.date),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() => _examList.removeAt(idx));
                                HapticService.light();
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 16),

                  // 3. In-Between Study Holidays Toggle (As explicitly requested by user!)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2825) : const Color(0xFFF2ECE1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _excludeGapDays ? AppColors.craftTeal.withAlpha(120) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Exclude Days Between Exams',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Gap days between exams will count as study leave / holidays (no regular classes counted in attendance).',
                                    style: TextStyle(fontSize: 11, color: AppColors.craftTeal),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _excludeGapDays,
                              activeThumbColor: AppColors.craftTeal,
                              onChanged: (val) {
                                setState(() => _excludeGapDays = val);
                                HapticService.selection();
                              },
                            ),
                          ],
                        ),
                        if (_excludeGapDays && gapCount > 0) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.craftTeal.withAlpha(isDark ? 45 : 30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.craftTeal),
                                const SizedBox(width: 4),
                                Text(
                                  '$gapCount in-between day(s) will be excluded from attendance',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.craftTeal),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 4. Record Exam Sessions Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Add exams as sessions to mark attendance',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    subtitle: const Text(
                      'Puts an exam class on your ledger so you can mark Present/Absent for each exam',
                      style: TextStyle(fontSize: 11),
                    ),
                    activeThumbColor: AppColors.craftTeal,
                    value: _createExamSessions,
                    onChanged: (val) => setState(() => _createExamSessions = val),
                  ),
                ],
              ),
            ),

            // ── FOOTER ACTIONS ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.craftTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _examList.isNotEmpty ? _applySchedule : null,
                      child: Text(
                        _examList.isEmpty ? 'Add Exams Above' : 'Apply Exam Schedule (${_examList.length})',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final borderColor = isSelected
        ? AppColors.craftTeal
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.craftTeal.withAlpha(isDark ? 40 : 25)
              : (isDark ? const Color(0xFF2C2825) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.craftTeal : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: isSelected ? AppColors.craftTeal : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
