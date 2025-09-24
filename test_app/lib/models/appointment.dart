enum AppointmentStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
}

enum Priority {
  low,
  medium,
  high,
}

class CaregiverAppointment {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final String caregiverId;
  final Duration duration;
  final AppointmentStatus status;
  final Priority priority;

  CaregiverAppointment({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.caregiverId,
    required this.duration,
    required this.status,
    required this.priority,
  });

  CaregiverAppointment copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? caregiverId,
    Duration? duration,
    AppointmentStatus? status,
    Priority? priority,
  }) {
    return CaregiverAppointment(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      caregiverId: caregiverId ?? this.caregiverId,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      priority: priority ?? this.priority,
    );
  }
}