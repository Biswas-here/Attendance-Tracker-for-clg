import 'dart:io';
import 'package:attendance_tracker/core/services/csv_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvImportService Tests', () {
    test('Parses CSV data lines correctly', () async {
      final tempDir = await Directory.systemTemp.createTemp('csv_test_');
      final testFile = File('${tempDir.path}/test_timetable.csv');

      await testFile.writeAsString('''day,class,room,start_time,end_time,subject,faculty,location
Monday,III BCA C,210,09:00,09:50,P&S,SS,
Monday,III BCA C,210,09:50,10:40,AI,DS,
Tuesday,III BCA C,210,09:00,10:40,AI LAB,DS,HP LAB A WING
Wednesday,III BCA C,210,10:40,11:30,DBMS,NN,
''');

      final result = await CsvImportService.parseFile(testFile.path);

      expect(result.rows.length, 4);
      expect(result.hasErrors, false);

      expect(result.rows[0].day, 'Monday');
      expect(result.rows[0].weekday, 1);
      expect(result.rows[0].startTime, '09:00');
      expect(result.rows[0].endTime, '09:50');
      expect(result.rows[0].subject, 'P&S');
      expect(result.rows[0].faculty, 'SS');

      expect(result.rows[2].day, 'Tuesday');
      expect(result.rows[2].weekday, 2);
      expect(result.rows[2].subject, 'AI LAB');
      expect(result.rows[2].location, 'HP LAB A WING');

      expect(result.uniqueSubjects, ['AI', 'AI LAB', 'DBMS', 'P&S']);

      await tempDir.delete(recursive: true);
    });

    test('generateDatesForWeekday generates correct occurrences', () {
      // Start on a Wednesday: 2026-11-11 is a Wednesday (weekday 3)
      final startDate = DateTime(2026, 11, 11);
      // Generate Mondays (weekday 1) for 3 weeks
      final dates = CsvImportService.generateDatesForWeekday(
        weekday: 1,
        startDate: startDate,
        numberOfWeeks: 3,
      );

      expect(dates.length, 3);
      for (final d in dates) {
        expect(d.weekday, 1); // all are Mondays
      }
      expect(dates[0], DateTime(2026, 11, 16));
      expect(dates[1], DateTime(2026, 11, 23));
      expect(dates[2], DateTime(2026, 11, 30));
    });
  });
}

