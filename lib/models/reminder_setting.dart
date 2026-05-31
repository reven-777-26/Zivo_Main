class ReminderSetting {
  final String label;
  final bool isEnabled;
  final String time; // e.g. "08:00 AM"

  ReminderSetting({
    required this.label,
    required this.isEnabled,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'isEnabled': isEnabled,
    'time': time,
  };

  factory ReminderSetting.fromJson(Map<String, dynamic> json) =>
      ReminderSetting(
        label: json['label'] ?? '',
        isEnabled: json['isEnabled'] ?? false,
        time: json['time'] ?? '08:00 AM',
      );
}
