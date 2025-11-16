import 'package:flutter/material.dart';
import 'dart:math';

import '../models/vital.dart'; // Use the new model
import '../models/vital_timeslot.dart';

class VitalsConfigPage extends StatelessWidget {
  final List<Vital> vitals;
  final void Function(Vital vital) addVital;
  final void Function(String id) deleteVital;
  final void Function(String id, Vital vital) updateVital;

  final List<VitalTimeslot> timeslots;
  final void Function(VitalTimeslot slot) addTimeslot;
  final void Function(String id) deleteTimeslot;


  const VitalsConfigPage({
    super.key,
    required this.vitals,
    required this.addVital,
    required this.deleteVital,
    required this.updateVital,
    required this.timeslots,
    required this.addTimeslot,
    required this.deleteTimeslot,
  });

  // --- VITAL CONFIG LOGIC ---\n
  Future<void> _editVitalDialog(BuildContext context, Vital vital) async {
    final TextEditingController nameController = TextEditingController(text: vital.name);
    final TextEditingController rangeController = TextEditingController(text: vital.normalRange);
    final TextEditingController unitController = TextEditingController(text: vital.unit); // New Unit Controller

    final result = await showDialog<Vital>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Vital Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Vital Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rangeController,
                decoration: const InputDecoration(labelText: 'Normal Range (e.g., 90-120/60-80)'),
              ),
              const SizedBox(height: 12),
              TextField( // New Unit Input
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Unit (e.g., mmHg, bpm, °F)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Return the updated Vital object
                Navigator.of(context).pop(
                  vital.copyWith(
                    name: nameController.text.trim(),
                    normalRange: rangeController.text.trim(),
                    unit: unitController.text.trim(), // Save the new unit
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      updateVital(vital.id, result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} updated successfully.')),
      );
    }
  }

  // Helper function to handle adding a new vital
  Future<void> _addVitalDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController rangeController = TextEditingController();
    final TextEditingController unitController = TextEditingController(); // New Unit Controller

    final result = await showDialog<Vital>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Vital'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Vital Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rangeController,
                decoration: const InputDecoration(labelText: 'Normal Range (e.g., 90-120/60-80)'),
              ),
              const SizedBox(height: 12),
              TextField( // New Unit Input
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Unit (e.g., mmHg, bpm, °F)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty || unitController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and Unit are required.')),
                  );
                  return;
                }
                
                // FIX 3: Passed the required 'unit' parameter when adding a new Vital.
                // Since this is a new vital, we use placeholder icon/color which can be edited later.
                final newVital = Vital(
                  id: Random().nextInt(100000).toString(), // Mock ID
                  name: nameController.text.trim(),
                  normalRange: rangeController.text.trim(),
                  unit: unitController.text.trim(), // Passed the new unit
                  icon: Icons.monitor_heart_outlined,
                  iconColor: Colors.blueGrey,
                );
                Navigator.of(context).pop(newVital);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      addVital(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} added successfully.')),
      );
    }
  }

  // Helper function to handle adding a new timeslot
  Future<void> _addTimeslotDialog(BuildContext context) async {
    final TextEditingController labelController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Time Slot'),
          content: TextField(
            controller: labelController,
            decoration: const InputDecoration(labelText: 'Time Slot Label (e.g., Morning Vitals, 7:00 AM)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (labelController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Time Slot Label is required.')),
                  );
                  return;
                }
                Navigator.of(context).pop(labelController.text.trim());
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      addTimeslot(VitalTimeslot(
        id: Random().nextInt(100000).toString(), // Mock ID
        label: result,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Time Slot "$result" added successfully.')),
      );
    }
  }

  // --- UI FOR CONFIGURATION PAGE ---\n

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Vital Types Configuration Section
          const Text(
            'Configured Vital Types',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 20),
          ...vitals.map((vital) => VitalConfigCard(
            title: vital.name,
            schedule: vital.normalRange, // Using normalRange here, schedule logic to be implemented later
            onEdit: () => _editVitalDialog(context, vital),
            onDelete: () => deleteVital(vital.id),
          )).toList(),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _addVitalDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add New Vital Type'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 40),

          // 2. Timeslots Configuration Section
          const Text(
            'Configured Time Slots',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 20),
          ...timeslots.map((slot) => TimeslotConfigCard(
            label: slot.label,
            onDelete: () => deleteTimeslot(slot.id),
          )).toList(),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _addTimeslotDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add New Time Slot'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// --- CONFIG CARD WIDGETS ---

class VitalConfigCard extends StatelessWidget {
  final String title;
  final String schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VitalConfigCard({
    super.key,
    required this.title,
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Normal Range: $schedule',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onEdit,
                child: const Text('Edit Details', style: TextStyle(color: Colors.blue)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onDelete,
                child: const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TimeslotConfigCard extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;

  const TimeslotConfigCard({
    super.key,
    required this.label,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          TextButton(
            onPressed: onDelete,
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
