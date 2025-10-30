import 'package:flutter/material.dart';

class Timeslot {
  final String id;
  final String label;
  final TimeOfDay time;


  Timeslot({
    required this.id,
    required this.label,
    required this.time,
  });

  Timeslot copyWith({
    String? id,
    String? label,
    TimeOfDay? time,
  }) {
    return Timeslot(
      id: id ?? this.id,
      label: label ?? this.label,
      time: time ?? this.time,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'time': time,
    };
  }
}
