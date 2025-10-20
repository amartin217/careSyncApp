class Medication {
  final String id;
  final String name;
  final String dosage;
  final List<String> timeslotIds;
  final Map<String, bool> isTakenByTimeslot;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.timeslotIds,
    Map<String, bool>? isTakenByTimeslot,
  }) : this.isTakenByTimeslot = isTakenByTimeslot ??
            {for (var tsId in timeslotIds) tsId: false};

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    List<String>? timeslotIds,
    Map<String, bool>? isTakenByTimeslot,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      timeslotIds: timeslotIds ?? this.timeslotIds,
      isTakenByTimeslot: isTakenByTimeslot ?? this.isTakenByTimeslot,
    );
  }
}