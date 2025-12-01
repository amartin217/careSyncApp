class VitalLog {
  final String id;
  final String vitalId;
  final String? timeslotId;
  final DateTime datetime;
  final double value;
  final String recorderId;

  VitalLog({
    required this.id,
    required this.vitalId,
    this.timeslotId,
    required this.datetime,
    required this.value,
    required this.recorderId,
  });

  VitalLog copyWith({
    String? id,
    String? vitalId,
    String? timeslotId,
    DateTime? datetime,
    double? value,
    String? recorderId,
  }) {
    return VitalLog(
      id: id ?? this.id,
      vitalId: vitalId ?? this.vitalId,
      timeslotId: timeslotId ?? this.timeslotId,
      datetime: datetime ?? this.datetime,
      value: value ?? this.value,
      recorderId: recorderId ?? this.recorderId,
    );
  }

  factory VitalLog.fromJson(Map<String, dynamic> json) {
    return VitalLog(
      id: json['vital_log_id'],
      vitalId: json['vital_id'],
      timeslotId: json['timeslot_id'],
      datetime: DateTime.parse(json['datetime']),
      value: (json['value'] as num).toDouble(),
      recorderId: json['recorder_id'],
    );
  }
}



