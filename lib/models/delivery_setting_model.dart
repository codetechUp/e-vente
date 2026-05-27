class DeliverySettingModel {
  final int? id;
  final String day; // Lundi, Mardi, etc.
  final int dayIndex; // 1 (Lundi) to 7 (Dimanche)
  final List<String> timeSlots;
  final bool isActive;

  DeliverySettingModel({
    this.id,
    required this.day,
    required this.dayIndex,
    required this.timeSlots,
    this.isActive = true,
  });

  factory DeliverySettingModel.fromJson(Map<String, dynamic> json) {
    return DeliverySettingModel(
      id: json['id'] as int?,
      day: json['day'] as String,
      dayIndex: json['day_index'] as int,
      timeSlots: List<String>.from(json['time_slots'] ?? []),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'day': day,
      'day_index': dayIndex,
      'time_slots': timeSlots,
      'is_active': isActive,
    };
  }

  DeliverySettingModel copyWith({
    int? id,
    String? day,
    int? dayIndex,
    List<String>? timeSlots,
    bool? isActive,
  }) {
    return DeliverySettingModel(
      id: id ?? this.id,
      day: day ?? this.day,
      dayIndex: dayIndex ?? this.dayIndex,
      timeSlots: timeSlots ?? this.timeSlots,
      isActive: isActive ?? this.isActive,
    );
  }
}
