import 'package:flutter/material.dart';

class Caregiver {
  final String id;
  final String name;
  final String role;
  final String phone;
  final String email;
  final Color color;
  final String avatar; // Initials for avatar

  Caregiver({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
    required this.color,
    required this.avatar,
  });
}