class AlarmSettings {
  final bool isEnabled;
  final bool isOnTimeEnabled;
  final bool isBeforeEnabled;
  final int offsetMinutes;
  final String time;

  AlarmSettings({
    this.isEnabled = false,
    this.isOnTimeEnabled = false,
    this.isBeforeEnabled = false,
    this.offsetMinutes = 5,
    this.time = '',
  });

  AlarmSettings copyWith({
    bool? isEnabled,
    bool? isOnTimeEnabled,
    bool? isBeforeEnabled,
    int? offsetMinutes,
    String? time,
  }) {
    return AlarmSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      isOnTimeEnabled: isOnTimeEnabled ?? this.isOnTimeEnabled,
      isBeforeEnabled: isBeforeEnabled ?? this.isBeforeEnabled,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      time: time ?? this.time,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'isOnTimeEnabled': isOnTimeEnabled,
      'isBeforeEnabled': isBeforeEnabled,
      'offsetMinutes': offsetMinutes,
      'time': time,
    };
  }

  factory AlarmSettings.fromMap(Map<String, dynamic> map) {
    return AlarmSettings(
      isEnabled: map['isEnabled'] ?? false,
      isOnTimeEnabled: map['isOnTimeEnabled'] ?? false,
      isBeforeEnabled: map['isBeforeEnabled'] ?? false,
      offsetMinutes: map['offsetMinutes'] ?? 5,
      time: map['time'] ?? '',
    );
  }

  @override
  String toString() {
    return 'AlarmSettings(isEnabled: $isEnabled, isOnTimeEnabled: $isOnTimeEnabled, '
           'isBeforeEnabled: $isBeforeEnabled, offsetMinutes: $offsetMinutes, time: $time)';
  }
} 