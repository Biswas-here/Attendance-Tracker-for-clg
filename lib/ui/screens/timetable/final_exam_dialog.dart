import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/class_session.dart';
import '../../../core/models/subject.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/nerdy_icons.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/settings_provider.dart';

enum FinalExamKind {
  theory,
  lab,
}

class FinalExamItem {
  DateTime date;
  String subjectId;
  String subjectName;
  int colorValue;
  FinalExamKind kind;
  String startTime;
  String endTime;
  String location;

  FinalExamItem({
    required this.date,
    required this.subjectId,
    required this.subjectName,
    required this.colorValue,
    required this.kind,
    required this.startTime,
    required this.endTime,
    required this.location,
  });
}

class FinalExamDialog extends StatefulWidget {
  final DateTime initialDate;

  const FinalExamDialog({
    super.key,
    required this.initialDate,
  });

  @override
  State<FinalExamDialog> createState() => _FinalExamDialogState();
}

class _FinalExamDialogState extends State<FinalExamDialog> {
  final List<FinalExamItem> _finalsList = [];

  // Form state
  late DateTime _selectedDate;
  String? _selectedSubjectId;
  FinalExamKind _selectedKind = FinalExamKind.theory;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 13, minute: 0);
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _locationController = TextEditingController(text: 'Exam Hall');
    final subjects = context.read<AttendanceProvider>().subjects;
    if (subjects.isNotEmpty) {
      _selectedSubjectId = subjects.first.id;
    }
    _loadSavedFinals();
  }

  Future<void> _loadSavedFinals() async {
    final attendance = context.read<AttendanceProvider>();
    final saved = await attendance.getSavedFinalsSchedule();
    if (saved != null && mounted) {
      final exams = saved['finals'] as List? ?? [];
      final subjects = attendance.subjects;
      final list = <FinalExamItem>[];
      for (final e in exams) {
        final dStr = e['date'] as String?;
        final sId = e['subjectId'] as String?;
        final kindStr = e['kind'] as String?;
        final sTime = e['startTime'] as String? ?? '10:00';
        final eTime = e['endTime'] as String? ?? '13:00';
        final loc = e['location'] as String? ?? 'Exam Hall';

        if (dStr != null && sId != null) {
          final sub = subjects.firstWhere(
            (s) => s.id == sId,
            orElse: () => subjects.isNotEmpty
                ? subjects.first
                : Subject(id: sId, name: e['subjectName'] as String? ?? 'Final Exam', colorValue: 0xFF3F7E7D),
          );
          final d = DateTime.tryParse(dStr);
          if (d != null) {
            list.add(FinalExamItem(
              date: d,
              subjectId: sId,
              subjectName: sub.name,
              colorValue: sub.colorValue,
              kind: kindStr == 'lab' ? FinalExamKind.lab : FinalExamKind.theory,
              startTime: sTime,
              endTime: eTime,
              location: loc,
            ));
          }
        }
      }

      setState(() {
        _finalsList.clear();
        _finalsList.addAll(list);
        _finalsList.sort((a, b) => a.date.compareTo(b.date));
      });
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _onKindChanged(FinalExamKind kind) {
    setState(() {
      _selectedKind = kind;
      if (kind == FinalExamKind.lab) {
        _startTime = const TimeOfDay(hour: 9, minute: 30);
        _endTime = const TimeOfDay(hour: 12, minute: 30);
        _locationController.text = 'Lab 1';
      } else {
        _startTime = const TimeOfDay(hour: 10, minute: 0);
        _endTime = const TimeOfDay(hour: 13, minute: 0);
        _locationController.text = 'Exam Hall';
      }
    });
    HapticService.selection();
  }

  void _addFinalExam() {
    if (_selectedSubjectId == null) return;
    final subjects = context.read<AttendanceProvider>().subjects;
    final sub = subjects.firstWhere(
      (s) => s.id == _selectedSubjectId,
      orElse: () => subjects.first,
    );

    final ymd = AppDateUtils.formatDateYmd(_selectedDate);
    final exists = _finalsList.any(
      (e) => AppDateUtils.formatDateYmd(e.date) == ymd && e.subjectId == sub.id && e.kind == _selectedKind,
    );
    if (exists) return;

    setState(() {
      _finalsList.add(FinalExamItem(
        date: _selectedDate,
        subjectId: sub.id,
        subjectName: sub.name,
        colorValue: sub.colorValue,
        kind: _selectedKind,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : (_selectedKind == FinalExamKind.lab ? 'Lab Room' : 'Exam Hall'),
      ));
      _finalsList.sort((a, b) => a.date.compareTo(b.date));
      _selectedDate = _selectedDate.add(const Duration(days: 2));
    });
    HapticService.selection();
  }

  Future<void> _applyFinalsSchedule() async {
    if (_finalsList.isEmpty) return;

    final attendance = context.read<AttendanceProvider>();
    final settings = context.read<SettingsProvider>().settings;

    // 1. Delete previous final exam sessions on any of these dates to prevent duplicates
    final dates = _finalsList.map((e) => AppDateUtils.formatDateYmd(e.date)).toSet();
    for (final d in dates) {
      await AppDatabase.instance.deleteExamSessionsForDate(d);
    }

    // 2. Insert new final exam sessions
    int created = 0;
    for (final exam in _finalsList) {
      final ymd = AppDateUtils.formatDateYmd(exam.date);
      final kindLabel = exam.kind == FinalExamKind.lab ? 'Lab Exam' : 'Theory Exam';
      final session = ClassSession(
        id: const Uuid().v4(),
        subjectId: exam.subjectId,
        date: ymd,
        startTime: exam.startTime,
        endTime: exam.endTime,
        room: '${exam.location} • $kindLabel',
        status: AttendanceStatus.unmarked,
        isExam: true,
      );
      await AppDatabase.instance.insertSession(session);
      created++;
    }

    // 3. Save configuration
    await attendance.saveFinalsSchedule({
      'finals': _finalsList.map((e) => {
        'date': AppDateUtils.formatDateYmd(e.date),
        'subjectId': e.subjectId,
        'subjectName': e.subjectName,
        'kind': e.kind == FinalExamKind.lab ? 'lab' : 'theory',
        'startTime': e.startTime,
        'endTime': e.endTime,
        'location': e.location,
      }).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    await attendance.loadData(showLoading: false, userSettings: settings);
    await attendance.syncAllUpcomingNotifications(settings);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Finals schedule applied! $created final exam session(s) saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearFinals() async {
    final attendance = context.read<AttendanceProvider>();
    final settings = context.read<SettingsProvider>().settings;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Finals Schedule?'),
        content: const Text('This will remove all scheduled final exams from your timetable.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.absent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final dates = _finalsList.map((e) => AppDateUtils.formatDateYmd(e.date)).toSet();
    for (final d in dates) {
      await AppDatabase.instance.deleteExamSessionsForDate(d);
    }

    await attendance.saveFinalsSchedule({'finals': []});
    await attendance.loadData(showLoading: false, userSettings: settings);
    await attendance.syncAllUpcomingNotifications(settings);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finals schedule cleared.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjects = context.watch<AttendanceProvider>().subjects;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: isDark ? const Color(0xFF262421) : const Color(0xFFFAF7F0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── COMPACT HEADER ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.kraftGold.withAlpha(isDark ? 45 : 30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school_rounded, color: AppColors.kraftGold, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Semester Finals Planner',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        Text(
                          'Schedule Final Theory & Lab / Practical Exams',
                          style: TextStyle(fontSize: 10.5, color: AppColors.kraftGold, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── COMPACT BODY ──────────────────────────────────────────
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                children: [
                  // 1. Choose Exam Kind: Theory vs Lab
                  const Text(
                    '1. Final Exam Type',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _kindChip(
                          title: 'Theory Exam',
                          subtitle: 'Written paper',
                          icon: Icons.article_outlined,
                          isSelected: _selectedKind == FinalExamKind.theory,
                          activeColor: AppColors.craftTeal,
                          onTap: () => _onKindChanged(FinalExamKind.theory),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _kindChip(
                          title: 'Lab / Practical',
                          subtitle: 'Viva & experiment',
                          icon: Icons.science_outlined,
                          isSelected: _selectedKind == FinalExamKind.lab,
                          activeColor: AppColors.craftPlum,
                          onTap: () => _onKindChanged(FinalExamKind.lab),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. Configure Exam Date, Subject & Location
                  const Text(
                    '2. Add Final Exam Paper',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2825) : const Color(0xFFF2ECE1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Date Picker
                            Expanded(
                              flex: 4,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF201D1A) : Colors.white,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.kraftGold),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          AppDateUtils.formatShortDate(_selectedDate),
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Subject Dropdown
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF201D1A) : Colors.white,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: subjects.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 7),
                                        child: Text('No subjects', style: TextStyle(fontSize: 11)),
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
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
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
                        const SizedBox(height: 6),

                        // Time & Location Row
                        Row(
                          children: [
                            // Start Time
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(7),
                                onTap: () async {
                                  final p = await showTimePicker(context: context, initialTime: _startTime);
                                  if (p != null) setState(() => _startTime = p);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF201D1A) : Colors.white,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    '${_formatTime(_startTime)} - ${_formatTime(_endTime)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Room / Lab field
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF201D1A) : Colors.white,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: TextField(
                                  controller: _locationController,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Hall / Lab name',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Add Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.kraftGold,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                            ),
                            onPressed: subjects.isNotEmpty ? _addFinalExam : null,
                            icon: const Icon(Icons.add, size: 15),
                            label: const Text('Add This Final', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Added Finals List
                  if (_finalsList.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_finalsList.length} Final Exam${_finalsList.length == 1 ? "" : "s"} Added:',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: AppColors.kraftGold),
                    ),
                    const SizedBox(height: 4),
                    ..._finalsList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final exam = entry.value;
                      final isLab = exam.kind == FinalExamKind.lab;
                      final tagColor = isLab ? AppColors.craftPlum : AppColors.craftTeal;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2825) : Colors.white,
                          borderRadius: BorderRadius.circular(7),
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
                              size: 24,
                              iconSize: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          exam.subjectName,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: tagColor.withAlpha(isDark ? 45 : 25),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isLab ? 'LAB' : 'THEORY',
                                          style: TextStyle(
                                            color: tagColor,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${AppDateUtils.formatShortDate(exam.date)} • ${exam.startTime} - ${exam.endTime} • ${exam.location}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.redAccent),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() => _finalsList.removeAt(idx));
                                HapticService.light();
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            // ── COMPACT FOOTER ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  if (_finalsList.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.absent,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      onPressed: _clearFinals,
                      child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kraftGold,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _finalsList.isNotEmpty ? _applyFinalsSchedule : null,
                      child: Text(
                        _finalsList.isEmpty ? 'Add Finals Above' : 'Apply Finals (${_finalsList.length})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
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

  Widget _kindChip({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final borderColor = isSelected
        ? activeColor
        : (isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 105,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withAlpha(isDark ? 45 : 30)
              : (isDark ? const Color(0xFF2C2825) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withAlpha(isDark ? 70 : 40)
                    : (isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? activeColor
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: isSelected ? activeColor : null,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
