import 'package:flutter/material.dart';

class Vital {
  final String id;
  String name;
  String normalRange;
  final String unit; // <--- NEW: Added unit for display
  final IconData icon; // Added for the LatestVitalCard
  final Color iconColor; // Added for the LatestVitalCard

  Vital({
    required this.id,
    required this.name,
    required this.normalRange,
    required this.unit, // <--- NEW: Must be provided
    required this.icon,
    required this.iconColor,
  });
  
  // Helper for creating new state (essential for setState updates)
  Vital copyWith({
    String? id,
    String? name,
    String? normalRange,
    String? unit, // <--- NEW: Added unit
    IconData? icon,
    Color? iconColor,
  }) {
    return Vital(
      id: id ?? this.id,
      name: name ?? this.name,
      normalRange: normalRange ?? this.normalRange,
      unit: unit ?? this.unit, // <--- NEW: Copy unit
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
    );
  }
}
