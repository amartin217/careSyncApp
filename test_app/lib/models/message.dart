class Message {
  final String id;
  final String text;
  final String fromId;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.text,
    required this.fromId,
    required this.timestamp,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      text: map['text'],
      fromId: map['from'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap(String patientId) {
    return {
      'id': id,
      'text': text,
      'from': fromId,
      'patient_id': patientId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
