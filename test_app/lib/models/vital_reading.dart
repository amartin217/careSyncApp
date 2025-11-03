class VitalReading {
  final String id;
  final String vitalId; // Links reading back to the Vital type (e.g., Blood Pressure)
  final double value;
  final DateTime timestamp;
  final String? unit;
  final String? notes;
  final int? systolic; // For Blood Pressure
  final int? diastolic; // For Blood Pressure

  VitalReading({
    required this.id,
    required this.vitalId,
    required this.value,
    required this.timestamp,
    this.unit,
    this.notes,
    this.systolic,
    this.diastolic,
  });
}
