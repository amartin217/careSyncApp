import 'package:flutter/material.dart';

/// Represents a scheduled time for recording a vital reading.
class VitalTimeslot {
  final String id;
  final String label;
  final TimeOfDay time; 

  const VitalTimeslot({
    required this.id,
    required this.label,
    required this.time,
  });

  VitalTimeslot copyWith({
    String? id,
    String? label,
    TimeOfDay? time,
  }) {
    return VitalTimeslot(
      id: id ?? this.id,
      label: label ?? this.label,
      time: time ?? this.time,
    );
  }
}