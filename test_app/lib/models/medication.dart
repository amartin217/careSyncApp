class Medication {
  final String id;
  final String name;
  final String dosage;
  final DateTime nextDose;
  final bool isTaken;
  final String frequency;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.nextDose,
    this.isTaken = false,
    this.frequency = 'Daily',
  });

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    DateTime? nextDose,
    bool? isTaken,
    String? frequency,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      nextDose: nextDose ?? this.nextDose,
      isTaken: isTaken ?? this.isTaken,
      frequency: frequency ?? this.frequency,
    );
  }
}