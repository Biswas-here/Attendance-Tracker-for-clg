import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// Represents one parsed row from the timetable CSV
class CsvTimetableRow {
  final String day;        // e.g. "Monday"
  final int weekday;       // 1=Mon, 2=Tue … 6=Sat, 7=Sun
  final String startTime;  // HH:MM
  final String endTime;    // HH:MM
  final String subject;
  final String? faculty;
  final String? room;
  final String? location;

  const CsvTimetableRow({
    required this.day,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.subject,
    this.faculty,
    this.room,
    this.location,
  });

  String? get displayRoom {
    final r = room?.trim();
    final loc = location?.trim();
    if (r != null && r.isNotEmpty && loc != null && loc.isNotEmpty) {
      return '$r ($loc)';
    }
    if (r != null && r.isNotEmpty) return r;
    if (loc != null && loc.isNotEmpty) return loc;
    return null;
  }
}

class CsvParseResult {
  final List<CsvTimetableRow> rows;
  final List<String> errors;
  final String filePath;

  const CsvParseResult({
    required this.rows,
    required this.errors,
    required this.filePath,
  });

  bool get hasErrors => errors.isNotEmpty;
  List<String> get uniqueSubjects =>
      rows.map((r) => r.subject).toSet().toList()..sort();
}

class CsvImportService {
  static const _dayMap = {
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 7,
  };

  /// Picks a CSV file and parses it.
  static Future<CsvParseResult?> pickAndParse() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (result.isEmpty || result.first.path == null) return null;

    final path = result.first.path!;
    return parseFile(path);
  }

  /// Parses a CSV file at [filePath].
  static Future<CsvParseResult> parseFile(String filePath) async {
    final file = File(filePath);
    final lines = await file.readAsLines();

    final rows = <CsvTimetableRow>[];
    final errors = <String>[];

    if (lines.isEmpty) {
      errors.add('File is empty.');
      return CsvParseResult(rows: rows, errors: errors, filePath: filePath);
    }

    // Parse header
    final header = _splitCsvLine(lines.first);
    final dayIdx = _findCol(header, ['day']);
    final startIdx = _findCol(header, ['start_time', 'start']);
    final endIdx = _findCol(header, ['end_time', 'end']);
    final subjectIdx = _findCol(header, ['subject']);
    final facultyIdx = _findCol(header, ['faculty', 'teacher']);
    final roomIdx = _findCol(header, ['room', 'class']);
    final locationIdx = _findCol(header, ['location']);

    if (dayIdx < 0 || startIdx < 0 || endIdx < 0 || subjectIdx < 0) {
      errors.add(
        'Required columns not found. Expected: day, start_time, end_time, subject.\n'
        'Found: ${header.join(", ")}',
      );
      return CsvParseResult(rows: rows, errors: errors, filePath: filePath);
    }

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _splitCsvLine(line);

      String safeGet(int idx) =>
          (idx >= 0 && idx < cols.length) ? cols[idx].trim() : '';

      final dayStr = safeGet(dayIdx);
      final startStr = safeGet(startIdx);
      final endStr = safeGet(endIdx);
      final subjectStr = safeGet(subjectIdx);

      if (dayStr.isEmpty || startStr.isEmpty || endStr.isEmpty || subjectStr.isEmpty) {
        errors.add('Row ${i + 1}: Skipped — missing required fields.');
        continue;
      }

      final weekday = _dayMap[dayStr.toLowerCase()];
      if (weekday == null) {
        errors.add('Row ${i + 1}: Unknown day "$dayStr" — skipped.');
        continue;
      }

      if (!_isValidTime(startStr) || !_isValidTime(endStr)) {
        errors.add('Row ${i + 1}: Invalid time "$startStr"-"$endStr" — skipped.');
        continue;
      }

      rows.add(CsvTimetableRow(
        day: dayStr,
        weekday: weekday,
        startTime: startStr,
        endTime: endStr,
        subject: subjectStr,
        faculty: safeGet(facultyIdx).isEmpty ? null : safeGet(facultyIdx),
        room: safeGet(roomIdx).isEmpty ? null : safeGet(roomIdx),
        location: safeGet(locationIdx).isEmpty ? null : safeGet(locationIdx),
      ));
    }

    return CsvParseResult(rows: rows, errors: errors, filePath: filePath);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int _findCol(List<String> header, List<String> candidates) {
    for (final c in candidates) {
      final idx = header.indexWhere((h) => h.toLowerCase().trim() == c);
      if (idx >= 0) return idx;
    }
    return -1;
  }

  static bool _isValidTime(String t) {
    final parts = t.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60;
  }

  /// Splits a CSV line, respecting double-quoted fields.
  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  /// Generate all dates matching a given [weekday] (1=Mon…7=Sun) within
  /// [startDate] + [numberOfWeeks].
  static List<DateTime> generateDatesForWeekday({
    required int weekday,
    required DateTime startDate,
    required int numberOfWeeks,
  }) {
    final dates = <DateTime>[];
    // Find first occurrence >= startDate
    var current = startDate;
    while (current.weekday != weekday) {
      current = current.add(const Duration(days: 1));
    }
    final endDate = startDate.add(Duration(days: numberOfWeeks * 7));
    while (current.isBefore(endDate)) {
      dates.add(current);
      current = current.add(const Duration(days: 7));
    }
    return dates;
  }
}

