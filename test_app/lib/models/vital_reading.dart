class VitalReading {
  final String id;
  final String type;
  final double value;
  final DateTime timestamp;
  final String? unit;
  final String? notes;

  VitalReading({
    required this.id,
    required this.type,
    required this.value,
    required this.timestamp,
    this.unit,
    this.notes,
  });
}