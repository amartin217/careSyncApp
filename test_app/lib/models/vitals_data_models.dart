import 'package:flutter/material.dart';

/// Represents a configurable type of vital sign the user wants to track.
class VitalType {
  final String id;
  String name;
  String normalRange;
  String unit;

  VitalType({
    required this.id,
    required this.name,
    required this.normalRange,
    required this.unit,
  });

  VitalType copyWith({
    String? id,
    String? name,
    String? normalRange,
    String? unit,
  }) {
    return VitalType(
      id: id ?? this.id,
      name: name ?? this.name,
      normalRange: normalRange ?? this.normalRange,
      unit: unit ?? this.unit,
    );
  }
}

/// Represents a single recorded instance of a vital reading.
class VitalReading {
  final String id;
  // Changed 'type' to 'vitalId' to link to the VitalType model (Fix for main.dart errors)
  final String vitalId; 
  final String value;
  final String unit; 
  final DateTime timestamp;

  // Constructor updated to accept vitalId instead of type
  VitalReading({
    required this.id,
    required this.vitalId, // Now required
    required this.value,
    required this.unit,
    required this.timestamp,
  });

  // Example factory constructor for placeholder data
  factory VitalReading.placeholder({
    required String id, 
    required String vitalId, // Now vitalId
    required String value, 
    required String unit,
  }) {
    return VitalReading(
      id: id,
      vitalId: vitalId,
      value: value,
      unit: unit,
      timestamp: DateTime.now(),
    );
  }
}