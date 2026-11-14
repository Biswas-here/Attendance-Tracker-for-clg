enum AttendanceStatus {
  unmarked,
  present,
  absent;

  String get value {
    switch (this) {
      case AttendanceStatus.present:
        return 'present';
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.unmarked:
        return 'unmarked';
    }
  }

  static AttendanceStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      default:
        return AttendanceStatus.unmarked;
    }
  }
}

class ClassSession {
  final String id;
  final String subjectId;
  final String? scheduleRuleId;
  final String date; // "YYYY-MM-DD"
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"
  final String? room;
  final AttendanceStatus status;
  final DateTime? markedAt;
  final DateTime createdAt;
  final bool isExam;

  ClassSession({
    required this.id,
    required this.subjectId,
    this.scheduleRuleId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.room,
    this.status = AttendanceStatus.unmarked,
    this.markedAt,
    DateTime? createdAt,
    this.isExam = false,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExamSession =>
      isExam || (room != null && room!.toLowerCase().contains('exam'));

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'schedule_rule_id': scheduleRuleId,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
      'status': status.value,
      'marked_at': markedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_exam': isExam ? 1 : 0,
    };
  }

  factory ClassSession.fromMap(Map<String, dynamic> map) {
    final roomVal = map['room'] as String?;
    final isExamCol = (map['is_exam'] as int?) == 1;
    final isExamRoom = roomVal != null && roomVal.toLowerCase().contains('exam');

    return ClassSession(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      scheduleRuleId: map['schedule_rule_id'] as String?,
      date: map['date'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      room: roomVal,
      status: AttendanceStatus.fromString(map['status'] as String?),
      markedAt: map['marked_at'] != null
          ? DateTime.tryParse(map['marked_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      isExam: isExamCol || isExamRoom,
    );
  }

  ClassSession copyWith({
    String? id,
    String? subjectId,
    String? scheduleRuleId,
    String? date,
    String? startTime,
    String? endTime,
    String? room,
    bool clearRoom = false,
    AttendanceStatus? status,
    DateTime? markedAt,
    DateTime? createdAt,
    bool? isExam,
  }) {
    return ClassSession(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      scheduleRuleId: scheduleRuleId ?? this.scheduleRuleId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: clearRoom ? null : (room ?? this.room),
      status: status ?? this.status,
      markedAt: markedAt ?? this.markedAt,
      createdAt: createdAt ?? this.createdAt,
      isExam: isExam ?? this.isExam,
    );
  }

  late final DateTime startDateTime = _parseDateTime(date, startTime);
  late final DateTime endDateTime = _parseDateTime(date, endTime);

  static DateTime _parseDateTime(String dStr, String tStr) {
    final parts = dStr.split('-');
    final timeParts = tStr.split(':');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
  }

  bool isCurrentlyActive([DateTime? now]) {
    final current = now ?? DateTime.now();
    final start = startDateTime;
    final end = endDateTime;
    return (current.isAfter(start) || current.isAtSameMomentAs(start)) &&
        current.isBefore(end);
  }
}

