import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/paper_button.dart';
import '../../widgets/paper_card.dart';

class ScheduleClassScreen extends StatefulWidget {
  final DateTime? initialDate;

  const ScheduleClassScreen({super.key, this.initialDate});

  @override
  State<ScheduleClassScreen> createState() => _ScheduleClassScreenState();
}

class _ScheduleClassScreenState extends State<ScheduleClassScreen> {
  final Set<String> _selectedSubjectIds = {};
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);

  bool _isRecurring = false;
  final Set<int> _recurringDays = {}; // 1 = Mon, 7 = Sun
  int _recurringWeeks = 8; // Default 8 weeks

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool _isValidTime() {
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    return endMin > startMin;
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveSchedule() async {
    if (_selectedSubjectIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one subject.')),
      );
      return;
    }

    if (!_isValidTime()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be later than start time.')),
      );
      return;
    }

    final attendance = context.read<AttendanceProvider>();
    final settings = context.read<SettingsProvider>().settings;

    if (settings.hasSemesterRange && !settings.isDateInSemester(_selectedDate)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Outside Semester Range'),
          content: Text(
            'The selected date is outside your active semester term (${AppDateUtils.formatShortDate(settings.semesterStartDateTime!)} to ${AppDateUtils.formatShortDate(settings.semesterEndDateTime!)}).\n\nClasses scheduled on this date will only appear during the semester bounds or if you clear the bounds.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.craftTeal),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Schedule Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      if (!mounted) return;
    }

    final startStr = _formatTimeOfDay(_startTime);
    final endStr = _formatTimeOfDay(_endTime);

    // Overlap check
    final overlaps = attendance.getOverlappingSessions(
      date: _selectedDate,
      startTime: startStr,
      endTime: endStr,
    );

    if (overlaps.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Schedule Overlap Warning'),
          content: Text(
            'This class time overlaps with ${overlaps.length} existing class(es) on ${AppDateUtils.formatDisplayDate(_selectedDate)}.\n\nDo you want to proceed anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.craftTeal),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    await attendance.scheduleClasses(
      subjectIds: _selectedSubjectIds.toList(),
      dates: [_selectedDate],
      startTime: startStr,
      endTime: endStr,
      recurringDaysOfWeek: _isRecurring && _recurringDays.isNotEmpty
          ? _recurringDays.toList()
          : null,
      recurringWeeks: _recurringWeeks,
      userSettings: settings,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Classes scheduled successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final subjects = attendance.subjects;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Class', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: subjects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Please add at least one subject before scheduling classes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Subject selection
                Text(
                  '1. SELECT SUBJECT(S)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: subjects.map((sub) {
                    final isSelected = _selectedSubjectIds.contains(sub.id);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(sub.name),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : null,
                      ),
                      selectedColor: Color(sub.colorValue),
                      checkmarkColor: Colors.white,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSubjectIds.add(sub.id);
                          } else {
                            _selectedSubjectIds.remove(sub.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Date selection
                Text(
                  '2. DATE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                PaperCard(
                  onTap: _pickDate,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: AppColors.craftTeal),
                      const SizedBox(width: 12),
                      Text(
                        AppDateUtils.formatDisplayDate(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Time range selection
                Text(
                  '3. CLASS TIMINGS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: PaperCard(
                        onTap: () => _pickTime(isStart: true),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Time',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _startTime.format(context),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PaperCard(
                        onTap: () => _pickTime(isStart: false),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _endTime.format(context),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: _isValidTime() ? null : AppColors.absent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_isValidTime()) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'End time must be after start time',
                    style: TextStyle(color: AppColors.absent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),

                // Recurring options
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Repeat Weekly (Recurring)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  subtitle: const Text('Schedule for repeating days over several weeks'),
                  value: _isRecurring,
                  activeTrackColor: AppColors.craftTeal,
                  onChanged: (val) => setState(() => _isRecurring = val),
                ),

                if (_isRecurring) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Select Days of the Week:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                      final isSelected = _recurringDays.contains(day);
                      final dayName = AppDateUtils.getWeekdayShort(day).substring(0, 1);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _recurringDays.remove(day);
                            } else {
                              _recurringDays.add(day);
                            }
                          });
                        },
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: isSelected
                              ? AppColors.craftTeal
                              : (isDark ? AppColors.darkCard : AppColors.lightCard),
                          child: Text(
                            dayName,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Repeat for:', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _recurringWeeks,
                        items: [2, 4, 8, 12, 16]
                            .map((w) => DropdownMenuItem(value: w, child: Text('$w weeks')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _recurringWeeks = val);
                        },
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 36),
                PaperButton(
                  text: 'Save Class Schedule',
                  icon: Icons.check,
                  fullWidth: true,
                  onPressed: _saveSchedule,
                ),
              ],
            ),
    );
  }
}

