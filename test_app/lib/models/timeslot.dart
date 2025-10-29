import 'package:flutter/material.dart';

class Timeslot {
  final String id;
  String label;
  TimeOfDay time;

  Timeslot({required this.label, required this.id, required this.time});
}