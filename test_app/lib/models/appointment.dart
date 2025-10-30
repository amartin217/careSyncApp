enum AppointmentStatus {
  scheduled,
  completed,
}

class CaregiverAppointment {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final String caregiverId;
  final Duration duration;
  final AppointmentStatus status;
  // final Priority priority;

  CaregiverAppointment({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.caregiverId,
    required this.duration,
    required this.status,
  });

  CaregiverAppointment copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? caregiverId,
    Duration? duration,
    AppointmentStatus? status,
    // Priority? priority,
  }) {
    return CaregiverAppointment(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      caregiverId: caregiverId ?? this.caregiverId,
      duration: duration ?? this.duration,
      status: status ?? this.status,
     
    );
  }
  
  Map<String, dynamic> toJson() {
  final endDateTime = dateTime.add(duration);

  return {
    'event_id': id,
    'name': title,
    'description': description,
    'start_datetime': dateTime.toIso8601String(),
    'end_datetime': endDateTime.toIso8601String(),
    'assigned_user': caregiverId,
    'is_completed': status == AppointmentStatus.completed,
  };
}

factory CaregiverAppointment.fromJson(Map<String, dynamic> json) {
  return CaregiverAppointment(
    id: json['event_id'] as String,
    title: json['name'] as String,
    description: json['description'] as String,
    dateTime: DateTime.parse(json['start_datetime'] as String),
    caregiverId: json['assigned_user'] as String,
    duration: DateTime.parse(json['end_datetime'] as String)
        .difference(DateTime.parse(json['start_datetime'] as String)),
    status: (json['is_completed'] as bool)
        ? AppointmentStatus.completed
        : AppointmentStatus.scheduled,
  );
}

}
