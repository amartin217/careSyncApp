import 'caregiver.dart';

class Message {
  final String id;
  final String text;
  final Caregiver from;
  final DateTime timestamp;

  Message ({
    required this.id,
    required this.text,
    required this.from,
    required this.timestamp,
  });
}
