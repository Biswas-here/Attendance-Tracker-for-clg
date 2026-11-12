import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';

class BackupResult {
  final bool success;
  final String message;

  BackupResult({required this.success, required this.message});
}

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  /// Export complete data as a JSON file and trigger share sheet
  Future<BackupResult> exportToJson() async {
    try {
      final data = await AppDatabase.instance.exportAllData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${tempDir.path}/attendance_backup_$dateStr.json');
      await file.writeAsString(jsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Attendance Tracker Backup',
          text: 'Backup created on ${DateTime.now()}',
        ),
      );

      return BackupResult(
        success: true,
        message: 'Backup generated successfully.',
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Failed to export backup: $e',
      );
    }
  }

  /// Export attendance history as CSV and trigger share sheet
  Future<BackupResult> exportToCsv() async {
    try {
      final subjects = await AppDatabase.instance.getAllSubjects();
      final subjectMap = {for (var s in subjects) s.id: s.name};
      final sessions = await AppDatabase.instance.getAllSessions();

      final buffer = StringBuffer();
      // CSV Header
      buffer.writeln('Session ID,Subject Name,Date,Start Time,End Time,Status,Marked At');

      for (final s in sessions) {
        final subName = subjectMap[s.subjectId] ?? 'Unknown Subject';
        final markedAt = s.markedAt?.toIso8601String() ?? '';
        // Escape commas
        final safeSubName = subName.contains(',') ? '"$subName"' : subName;
        buffer.writeln('${s.id},$safeSubName,${s.date},${s.startTime},${s.endTime},${s.status.value},$markedAt');
      }

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${tempDir.path}/attendance_records_$dateStr.csv');
      await file.writeAsString(buffer.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Attendance Records CSV',
          text: 'Attendance records exported on ${DateTime.now()}',
        ),
      );

      return BackupResult(
        success: true,
        message: 'CSV file exported successfully.',
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Failed to export CSV: $e',
      );
    }
  }

  /// Import and restore from user-selected JSON file
  Future<BackupResult> pickAndRestoreJson() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty || files.first.path == null) {
        return BackupResult(success: false, message: 'No file selected.');
      }

      final file = File(files.first.path!);
      final content = await file.readAsString();

      dynamic parsedJson;
      try {
        parsedJson = jsonDecode(content);
      } catch (e) {
        return BackupResult(
          success: false,
          message: 'Selected file is not valid JSON.',
        );
      }

      if (parsedJson is! Map<String, dynamic>) {
        return BackupResult(
          success: false,
          message: 'Invalid backup format.',
        );
      }

      // Validate required keys
      if (!parsedJson.containsKey('subjects') || !parsedJson.containsKey('sessions')) {
        return BackupResult(
          success: false,
          message: 'File is missing required attendance backup structures.',
        );
      }

      await AppDatabase.instance.restoreAllData(parsedJson);

      return BackupResult(
        success: true,
        message: 'Data restored successfully!',
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Failed to restore backup: $e',
      );
    }
  }
}
