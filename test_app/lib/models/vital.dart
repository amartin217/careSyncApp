class Vital {
  final String id;
  String name;
  String units;
  String notes;
  List<String> timeslotIds;

  Vital({
    required this.id,
    required this.name,
    required this.units,
    this.notes = '',
    required this.timeslotIds,
  });

  Vital copyWith({
    String? id,
    String? name,
    String? units,
    String? notes,
    List<String>? timeslotIds,
  }) {
    return Vital(
      id: id ?? this.id,
      name: name ?? this.name,
      units: units ?? this.units,
      notes: notes ?? this.notes,
      timeslotIds: timeslotIds ?? this.timeslotIds,
    );
  }

  factory Vital.fromJson(Map<String, dynamic> json) {
    return Vital(
      id: json['vital_id'],
      name: json['name'],
      units: json['units'] ?? '',
      notes: json['notes'] ?? '',
      timeslotIds:
          (json['timeslot_ids'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}



