import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/class_schedule_rule.dart';
import '../../../core/models/class_session.dart';
import '../../../core/services/csv_import_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/paper_card.dart';

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  // State
  CsvParseResult? _parseResult;
  bool _isParsing = false;
  bool _isImporting = false;

  // Subject selection — which unique subjects to import
  final Set<String> _selectedSubjects = {};

  // Date range
  DateTime _startDate = DateTime.now();
  int _numberOfWeeks = 4;

  // ── File picker ──────────────────────────────────────────────────────────
  Future<void> _pickAndParseCsv() async {
    setState(() => _isParsing = true);
    try {
      final result = await CsvImportService.pickAndParse();
      if (result == null) {
        setState(() => _isParsing = false);
        return;
      }
      setState(() {
        _parseResult = result;
        _selectedSubjects
          ..clear()
          ..addAll(result.uniqueSubjects);
        _isParsing = false;
      });
    } catch (e) {
      setState(() => _isParsing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e')),
        );
      }
    }
  }

  // ── Import ───────────────────────────────────────────────────────────────
  Future<void> _doImport() async {
    if (_parseResult == null || _selectedSubjects.isEmpty) return;

    setState(() => _isImporting = true);

    final attendance = context.read<AttendanceProvider>();

    int subjectsCreated = 0;
    int sessionsScheduled = 0;
    int duplicatesSkipped = 0;

    // Build a map of first teacher/faculty and room found in the CSV for each subject
    final subjectFacultyMap = <String, String>{};
    final subjectRoomMap = <String, String>{};
    for (final row in _parseResult!.rows) {
      if (_selectedSubjects.contains(row.subject)) {
        if (!subjectFacultyMap.containsKey(row.subject) &&
            row.faculty != null &&
            row.faculty!.trim().isNotEmpty) {
          subjectFacultyMap[row.subject] = row.faculty!.trim();
        }
        if (!subjectRoomMap.containsKey(row.subject) &&
            row.displayRoom != null &&
            row.displayRoom!.trim().isNotEmpty) {
          subjectRoomMap[row.subject] = row.displayRoom!.trim();
        }
      }
    }

    // Build a map: existing subject name → id
    final existingSubMap = {
      for (final s in attendance.subjects) s.name.toLowerCase(): s
    };

    // For each selected subject, ensure the subject exists and has faculty/room metadata
    final subjectNameToId = <String, String>{};
    for (final subName in _selectedSubjects) {
      final existing = existingSubMap[subName.toLowerCase()];
      if (existing != null) {
        subjectNameToId[subName] = existing.id;
        // If existing subject is missing teacher or room, update with CSV data
        final csvTeacher = subjectFacultyMap[subName];
        final csvRoom = subjectRoomMap[subName];
        if ((existing.teacher == null && csvTeacher != null) ||
            (existing.room == null && csvRoom != null)) {
          await attendance.updateSubject(
            existing.copyWith(
              teacher: existing.teacher ?? csvTeacher,
              room: existing.room ?? csvRoom,
            ),
          );
        }
      } else {
        // Create subject with faculty and room from CSV
        await attendance.addSubject(
          name: subName,
          teacher: subjectFacultyMap[subName],
          room: subjectRoomMap[subName],
          allowDuplicate: false,
        );
        // Find the newly created subject
        final created = attendance.subjects
            .where((s) => s.name.toLowerCase() == subName.toLowerCase())
            .firstOrNull;
        if (created != null) {
          subjectNameToId[subName] = created.id;
          subjectsCreated++;
        }
      }
    }

    // Build set of existing session fingerprints to deduplicate
    final existingFingerprints = {
      for (final s in attendance.allSessions)
        '${s.subjectId}|${s.date}|${s.startTime}'
    };

    // Batch accumulate rules and sessions
    final newRules = <ClassScheduleRule>[];
    final newSessions = <ClassSession>[];

    // For each row in the parse result, generate dates and schedule
    for (final row in _parseResult!.rows) {
      if (!_selectedSubjects.contains(row.subject)) continue;
      final subjectId = subjectNameToId[row.subject];
      if (subjectId == null) continue;

      // Prepare schedule rule
      newRules.add(
        ClassScheduleRule(
          id: 'rule_${subjectId}_${row.weekday}_${row.startTime.replaceAll(':', '')}',
          subjectId: subjectId,
          dayOfWeek: row.weekday,
          startTime: row.startTime,
          endTime: row.endTime,
          room: row.displayRoom,
        ),
      );

      final dates = CsvImportService.generateDatesForWeekday(
        weekday: row.weekday,
        startDate: _startDate,
        numberOfWeeks: _numberOfWeeks,
      );

      for (final date in dates) {
        final dateStr = AppDateUtils.formatDateYmd(date);
        final fingerprint = '$subjectId|$dateStr|${row.startTime}';

        if (existingFingerprints.contains(fingerprint)) {
          duplicatesSkipped++;
          continue;
        }

        existingFingerprints.add(fingerprint);

        newSessions.add(
          ClassSession(
            id: 'session_${subjectId}_${dateStr}_${row.startTime.replaceAll(':', '')}',
            subjectId: subjectId,
            date: dateStr,
            startTime: row.startTime,
            endTime: row.endTime,
            room: row.displayRoom,
            status: AttendanceStatus.unmarked,
          ),
        );
        sessionsScheduled++;
      }
    }

    // High performance batch writes to SQLite
    if (newRules.isNotEmpty) {
      await AppDatabase.instance.insertScheduleRulesBatch(newRules);
    }
    if (newSessions.isNotEmpty) {
      await AppDatabase.instance.insertSessionsBatch(newSessions);
      // Reload provider state once at the end
      await attendance.loadData();
      if (mounted) {
        final settingsProv = context.read<SettingsProvider>();
        await attendance.syncAllUpcomingNotifications(settingsProv.settings);
      }
    }

    setState(() => _isImporting = false);

    if (mounted) {
      _showImportSummaryDialog(
        subjectsCreated: subjectsCreated,
        sessionsScheduled: sessionsScheduled,
        duplicatesSkipped: duplicatesSkipped,
      );
    }
  }

  void _showImportSummaryDialog({
    required int subjectsCreated,
    required int sessionsScheduled,
    required int duplicatesSkipped,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.present, size: 24),
            SizedBox(width: 10),
            Text('Import Complete', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow(Icons.book_outlined, AppColors.craftTeal,
                '$subjectsCreated new subjects created'),
            const SizedBox(height: 8),
            _summaryRow(Icons.calendar_today_outlined, AppColors.present,
                '$sessionsScheduled classes scheduled'),
            const SizedBox(height: 8),
            _summaryRow(Icons.skip_next_outlined, AppColors.unmarked,
                '$duplicatesSkipped duplicates skipped'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.craftTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Import Timetable CSV',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // ── STEP 1: File selection ─────────────────────────────────────
          _stepHeader('1', 'Select CSV File', isDark),
          const SizedBox(height: 10),
          _buildFilePicker(isDark),

          if (_parseResult != null) ...[
            const SizedBox(height: 24),

            // ── STEP 2: Date range ──────────────────────────────────────
            _stepHeader('2', 'Set Import Date Range', isDark),
            const SizedBox(height: 10),
            _buildDateRangePicker(isDark),
            const SizedBox(height: 24),

            // ── STEP 3: Subject selection ───────────────────────────────
            _stepHeader('3', 'Choose Subjects to Import', isDark),
            const SizedBox(height: 4),
            Text(
              'Deselect subjects you don\'t want scheduled (e.g. YOGA, Language).',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _buildSubjectSelector(isDark),
            const SizedBox(height: 24),

            // ── STEP 4: Preview ─────────────────────────────────────────
            _stepHeader('4', 'Preview', isDark),
            const SizedBox(height: 10),
            _buildPreviewCard(isDark),
            const SizedBox(height: 24),

            // ── IMPORT BUTTON ───────────────────────────────────────────
            _buildImportButton(),
          ],
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _stepHeader(String number, String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.craftTeal,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.craftTeal.withAlpha(50),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildFilePicker(bool isDark) {
    return PaperCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_parseResult == null) ...[
            const Text(
              'Select a CSV timetable file. Required columns:',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'day, start_time, end_time, subject',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.present, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'File loaded: ${_parseResult!.filePath.split('/').last.split('\\').last}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_parseResult!.rows.length} valid rows, '
              '${_parseResult!.uniqueSubjects.length} unique subjects found',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            if (_parseResult!.hasErrors) ...[
              const SizedBox(height: 8),
              Text(
                '⚠ ${_parseResult!.errors.length} row(s) skipped — tap to review',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.kraftGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _parseResult == null ? AppColors.craftTeal : AppColors.craftIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isParsing ? null : _pickAndParseCsv,
              icon: _isParsing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(_parseResult == null ? Icons.upload_file_rounded : Icons.refresh),
              label: Text(
                _parseResult == null ? 'Pick CSV File' : 'Pick Different File',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker(bool isDark) {
    return PaperCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The CSV contains a recurring weekday schedule (Mon–Sat). '
            'Choose the start date and how many weeks to generate sessions for.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.craftTeal),
                            const SizedBox(width: 8),
                            Text(
                              AppDateUtils.formatDisplayDate(_startDate),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
                    const Text('Number of Weeks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: DropdownButton<int>(
                        value: _numberOfWeeks,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: [1, 2, 4, 8, 12, 16, 20, 24, 36, 52]
                            .map((w) => DropdownMenuItem(
                                  value: w,
                                  child: Text(
                                    '$w week${w == 1 ? '' : 's'}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _numberOfWeeks = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector(bool isDark) {
    if (_parseResult == null) return const SizedBox();
    final subjects = _parseResult!.uniqueSubjects;

    return PaperCard(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: subjects.map((sub) {
          final isSelected = _selectedSubjects.contains(sub);
          return CheckboxListTile(
            value: isSelected,
            activeColor: AppColors.craftTeal,
            title: Text(sub, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(
              '${_parseResult!.rows.where((r) => r.subject == sub).length} class occurrences/week pattern',
              style: const TextStyle(fontSize: 11),
            ),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedSubjects.add(sub);
                } else {
                  _selectedSubjects.remove(sub);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPreviewCard(bool isDark) {
    if (_parseResult == null) return const SizedBox();

    // Calculate estimated sessions
    int estimatedSessions = 0;
    for (final sub in _selectedSubjects) {
      final rows = _parseResult!.rows.where((r) => r.subject == sub).toList();
      // Each row has a weekday — unique weekday+time combos × numberOfWeeks
      for (final row in rows) {
        final dates = CsvImportService.generateDatesForWeekday(
          weekday: row.weekday,
          startDate: _startDate,
          numberOfWeeks: _numberOfWeeks,
        );
        estimatedSessions += dates.length;
      }
    }

    final endDate = _startDate.add(Duration(days: _numberOfWeeks * 7 - 1));

    return PaperCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _previewChip('${_selectedSubjects.length}', 'Subjects', AppColors.craftTeal),
              const SizedBox(width: 8),
              _previewChip('$_numberOfWeeks', 'Weeks', AppColors.craftIndigo),
              const SizedBox(width: 8),
              _previewChip('~$estimatedSessions', 'Sessions', AppColors.present),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Date range: ${AppDateUtils.formatDisplayDate(_startDate)} → ${AppDateUtils.formatDisplayDate(endDate)}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'All imported sessions will be marked UNMARKED (no auto-attendance).',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton() {
    final canImport = _parseResult != null && _selectedSubjects.isNotEmpty && !_isImporting;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: canImport ? AppColors.present : AppColors.unmarked,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: canImport ? 4 : 0,
        ),
        onPressed: canImport ? _doImport : null,
        icon: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.download_done_rounded, size: 22),
        label: Text(
          _isImporting ? 'Importing…' : 'Import Timetable',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
        ),
      ),
    );
  }
}

