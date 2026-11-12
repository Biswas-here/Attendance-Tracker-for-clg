class ClassScheduleRule {
  final String id;
  final String subjectId;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday (matching DateTime.weekday)
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"
  final String? room;
  final DateTime createdAt;

  ClassScheduleRule({
    required this.id,
    required this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ClassScheduleRule.fromMap(Map<String, dynamic> map) {
    return ClassScheduleRule(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      room: map['room'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}

