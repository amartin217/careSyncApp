class Medication {
  final String id;
  String name;
  String dosage;
  String notes;
  List<String> timeslotIds;
  Map<String, bool> isTakenByTimeslot;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    this.notes = 'N/A',
    required this.timeslotIds,
    Map<String, bool>? isTakenByTimeslot,
  }) : this.isTakenByTimeslot = isTakenByTimeslot ??
            {for (var tsId in timeslotIds) tsId: false};

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    String? notes,
    List<String>? timeslotIds,
    Map<String, bool>? isTakenByTimeslot,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      notes: notes ?? this.notes,
      timeslotIds: timeslotIds ?? this.timeslotIds,
      isTakenByTimeslot: isTakenByTimeslot ?? this.isTakenByTimeslot,
    );
  }
}