class Subject {
  final String id;
  final String name;
  final String? code;
  final String? teacher;
  final String? room;
  final double? targetPercentage;
  final int colorValue;
  final DateTime createdAt;

  Subject({
    required this.id,
    required this.name,
    this.code,
    this.teacher,
    this.room,
    this.targetPercentage,
    this.colorValue = 0xFF5C6BC0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'teacher': teacher,
      'room': room,
      'target_percentage': targetPercentage,
      'color_value': colorValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String?,
      teacher: map['teacher'] as String?,
      room: map['room'] as String?,
      targetPercentage: map['target_percentage'] != null
          ? (map['target_percentage'] as num).toDouble()
          : null,
      colorValue: map['color_value'] != null ? (map['color_value'] as int) : 0xFF5C6BC0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  Subject copyWith({
    String? id,
    String? name,
    String? code,
    bool clearCode = false,
    String? teacher,
    bool clearTeacher = false,
    String? room,
    bool clearRoom = false,
    double? targetPercentage,
    bool clearTargetPercentage = false,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      code: clearCode ? null : (code ?? this.code),
      teacher: clearTeacher ? null : (teacher ?? this.teacher),
      room: clearRoom ? null : (room ?? this.room),
      targetPercentage: clearTargetPercentage ? null : (targetPercentage ?? this.targetPercentage),
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

