import 'package:flutter/material.dart';

// note: I got rid of role, phone, email, and avatar. If we want these, we 
// need to edit profile table

class Caregiver {
  final String id;
  final String name;
  final Color color;

  Caregiver({
    required this.id,
    required this.name,
    required this.color,
  });
}