import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/subject.dart';
import '../models/class_schedule_rule.dart';
import '../models/class_session.dart';
import '../models/user_settings.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance_ledger.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE user_settings ADD COLUMN profile_image_path TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE user_settings ADD COLUMN saturday_holiday_pattern TEXT DEFAULT "second_fourth"');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE user_settings ADD COLUMN custom_holidays TEXT DEFAULT ""');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE user_settings ADD COLUMN haptic_feedback_enabled INTEGER DEFAULT 1');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE user_settings ADD COLUMN semester_start_date TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE user_settings ADD COLUMN semester_end_date TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE class_sessions ADD COLUMN room TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE class_schedule_rules ADD COLUMN room TEXT');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE subjects ADD COLUMN room TEXT');
      } catch (_) {}
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE subjects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT,
        teacher TEXT,
        room TEXT,
        target_percentage REAL,
        color_value INTEGER DEFAULT 4284247232,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE class_schedule_rules (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        room TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE class_sessions (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        schedule_rule_id TEXT,
        date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        room TEXT,
        status TEXT NOT NULL,
        marked_at TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        theme_mode TEXT NOT NULL,
        default_attendance_target REAL NOT NULL,
        student_name TEXT NOT NULL,
        institution_name TEXT NOT NULL,
        course_name TEXT NOT NULL,
        semester TEXT NOT NULL,
        notifications_enabled INTEGER NOT NULL,
        advance_reminder_enabled INTEGER NOT NULL,
        advance_reminder_minutes INTEGER NOT NULL,
        haptic_feedback_enabled INTEGER NOT NULL DEFAULT 1,
        profile_image_path TEXT,
        saturday_holiday_pattern TEXT DEFAULT 'second_fourth',
        custom_holidays TEXT DEFAULT '',
        semester_start_date TEXT,
        semester_end_date TEXT
      )
    ''');

    // Default settings
    await db.insert('user_settings', {
      'id': 1,
      'theme_mode': 'system',
      'default_attendance_target': 75.0,
      'student_name': '',
      'institution_name': '',
      'course_name': '',
      'semester': '',
      'notifications_enabled': 1,
      'advance_reminder_enabled': 0,
      'advance_reminder_minutes': 5,
      'haptic_feedback_enabled': 1,
      'profile_image_path': null,
      'saturday_holiday_pattern': 'second_fourth',
      'custom_holidays': '',
      'semester_start_date': null,
      'semester_end_date': null,
    });
  }

  // --- SUBJECTS ---
  Future<List<Subject>> getAllSubjects() async {
    final db = await database;
    final result = await db.query('subjects', orderBy: 'name COLLATE NOCASE ASC');
    return result.map((map) => Subject.fromMap(map)).toList();
  }

  Future<Subject?> getSubjectById(String id) async {
    final db = await database;
    final result = await db.query(
      'subjects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Subject.fromMap(result.first);
    }
    return null;
  }

  Future<Subject?> getSubjectByName(String name) async {
    final db = await database;
    final result = await db.query(
      'subjects',
      where: 'LOWER(name) = ?',
      whereArgs: [name.trim().toLowerCase()],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Subject.fromMap(result.first);
    }
    return null;
  }

  Future<int> insertSubject(Subject subject) async {
    final db = await database;
    return await db.insert('subjects', subject.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateSubject(Subject subject) async {
    final db = await database;
    final res = await db.update(
      'subjects',
      subject.toMap(),
      where: 'id = ?',
      whereArgs: [subject.id],
    );

    // Sync room to all class_sessions and class_schedule_rules for this subject
    await db.update(
      'class_sessions',
      {'room': subject.room},
      where: 'subject_id = ?',
      whereArgs: [subject.id],
    );
    await db.update(
      'class_schedule_rules',
      {'room': subject.room},
      where: 'subject_id = ?',
      whereArgs: [subject.id],
    );

    return res;
  }

  Future<int> deleteSubject(String id) async {
    final db = await database;
    // Manual deletion of dependent sessions and schedule rules to ensure consistency
    await db.delete('class_sessions', where: 'subject_id = ?', whereArgs: [id]);
    await db.delete('class_schedule_rules', where: 'subject_id = ?', whereArgs: [id]);
    return await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  // --- CLASS SCHEDULE RULES ---
  Future<List<ClassScheduleRule>> getAllScheduleRules() async {
    final db = await database;
    final result = await db.query('class_schedule_rules');
    return result.map((map) => ClassScheduleRule.fromMap(map)).toList();
  }

  Future<int> insertScheduleRule(ClassScheduleRule rule) async {
    final db = await database;
    return await db.insert('class_schedule_rules', rule.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertScheduleRulesBatch(List<ClassScheduleRule> rules) async {
    final db = await database;
    final batch = db.batch();
    for (final rule in rules) {
      batch.insert('class_schedule_rules', rule.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> deleteScheduleRule(String id) async {
    final db = await database;
    return await db.delete('class_schedule_rules', where: 'id = ?', whereArgs: [id]);
  }

  // --- CLASS SESSIONS ---
  Future<List<ClassSession>> getAllSessions() async {
    final db = await database;
    final result = await db.query('class_sessions', orderBy: 'date ASC, start_time ASC');
    return result.map((map) => ClassSession.fromMap(map)).toList();
  }

  Future<List<ClassSession>> getSessionsForDate(String date) async {
    final db = await database;
    final result = await db.query(
      'class_sessions',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'start_time ASC',
    );
    return result.map((map) => ClassSession.fromMap(map)).toList();
  }

  Future<List<ClassSession>> getSessionsForSubject(String subjectId) async {
    final db = await database;
    final result = await db.query(
      'class_sessions',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'date DESC, start_time DESC',
    );
    return result.map((map) => ClassSession.fromMap(map)).toList();
  }

  Future<int> insertSession(ClassSession session) async {
    final db = await database;
    return await db.insert('class_sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertSessionsBatch(List<ClassSession> sessions) async {
    final db = await database;
    final batch = db.batch();
    for (final session in sessions) {
      batch.insert('class_sessions', session.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> updateSessionStatus(String sessionId, AttendanceStatus status) async {
    final db = await database;
    return await db.update(
      'class_sessions',
      {
        'status': status.value,
        'marked_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<int> updateSession(ClassSession session) async {
    final db = await database;
    return await db.update(
      'class_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<int> deleteSession(String id) async {
    final db = await database;
    return await db.delete('class_sessions', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all sessions on a given date (e.g. when declaring a holiday or full-day exam)
  Future<int> deleteSessionsForDate(String dateStr) async {
    final db = await database;
    return await db.delete('class_sessions', where: 'date = ?', whereArgs: [dateStr]);
  }

  /// Delete sessions on a given date that overlap with a time range (e.g. for half-day exams)
  Future<int> deleteSessionsOverlappingTime(String dateStr, String startTime, String endTime) async {
    final db = await database;
    return await db.delete(
      'class_sessions',
      where: 'date = ? AND start_time < ? AND end_time > ?',
      whereArgs: [dateStr, endTime, startTime],
    );
  }

  /// Delete unmarked sessions outside the given date range (e.g. when shrinking semester bounds)
  Future<int> deleteUnmarkedSessionsOutsideRange(String startDateStr, String endDateStr) async {
    final db = await database;
    return await db.delete(
      'class_sessions',
      where: 'status = ? AND (date < ? OR date > ?)',
      whereArgs: [AttendanceStatus.unmarked.name, startDateStr, endDateStr],
    );
  }

  // --- SETTINGS ---
  Future<UserSettings> getSettings() async {
    final db = await database;
    final result = await db.query('user_settings', where: 'id = 1');
    if (result.isNotEmpty) {
      return UserSettings.fromMap(result.first);
    }
    return UserSettings();
  }

  Future<int> updateSettings(UserSettings settings) async {
    final db = await database;
    final map = settings.toMap();
    map['id'] = 1;
    return await db.update('user_settings', map, where: 'id = 1');
  }

  // --- EXPORT & RESTORE ---
  Future<Map<String, dynamic>> exportAllData() async {
    final subjects = await getAllSubjects();
    final rules = await getAllScheduleRules();
    final sessions = await getAllSessions();
    final settings = await getSettings();

    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'subjects': subjects.map((s) => s.toMap()).toList(),
      'schedule_rules': rules.map((r) => r.toMap()).toList(),
      'sessions': sessions.map((sess) => sess.toMap()).toList(),
      'settings': settings.toMap(),
    };
  }

  Future<void> restoreAllData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('class_sessions');
      await txn.delete('class_schedule_rules');
      await txn.delete('subjects');

      final subjectsList = (data['subjects'] as List<dynamic>?) ?? [];
      for (final s in subjectsList) {
        await txn.insert('subjects', Map<String, dynamic>.from(s as Map));
      }

      final rulesList = (data['schedule_rules'] as List<dynamic>?) ?? [];
      for (final r in rulesList) {
        await txn.insert('class_schedule_rules', Map<String, dynamic>.from(r as Map));
      }

      final sessionsList = (data['sessions'] as List<dynamic>?) ?? [];
      for (final sess in sessionsList) {
        await txn.insert('class_sessions', Map<String, dynamic>.from(sess as Map));
      }

      if (data['settings'] != null) {
        final settingsMap = Map<String, dynamic>.from(data['settings'] as Map);
        settingsMap['id'] = 1;
        await txn.update('user_settings', settingsMap, where: 'id = 1');
      }
    });
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('class_sessions');
      await txn.delete('class_schedule_rules');
      await txn.delete('subjects');
      await txn.update(
        'user_settings',
        {
          'theme_mode': 'system',
          'default_attendance_target': 75.0,
          'student_name': '',
          'institution_name': '',
          'course_name': '',
          'semester': '',
          'notifications_enabled': 1,
          'advance_reminder_enabled': 0,
          'advance_reminder_minutes': 10,
          'profile_image_path': null,
          'saturday_holiday_pattern': 'second_fourth',
          'custom_holidays': '',
        },
        where: 'id = 1',
      );
    });
  }
}

