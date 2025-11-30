import 'package:flutter/material.dart';
import '../models/vitals_data_models.dart';
import '../models/vital_timeslot.dart';

/// A comprehensive widget for managing Vitals setup (types and timeslots).
class MyVitalsConfigurationTab extends StatelessWidget {
  final List<VitalType> configuredVitals;
  final List<VitalTimeslot> timeslots;
  final Function(VitalType) onAddVital;
  final Function(String, VitalType) onUpdateVital;
  final Function(String) onDeleteVital;
  final Function(VitalTimeslot) onAddTimeslot;
  final Function(String) onDeleteTimeslot;

  const MyVitalsConfigurationTab({
    super.key,
    required this.configuredVitals,
    required this.timeslots,
    required this.onAddVital,
    required this.onUpdateVital,
    required this.onDeleteVital,
    required this.onAddTimeslot,
    required this.onDeleteTimeslot,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // --- Vital Types Configuration ---
        _buildSectionHeader(context, 'Vital Signs to Track', Icons.monitor_heart),
        ...configuredVitals.map((vital) => _buildVitalTile(context, vital)).toList(),
        ElevatedButton.icon(
          onPressed: () => _showAddEditVitalDialog(context),
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Add New Vital Sign'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            foregroundColor: Theme.of(context).primaryColor,
            elevation: 0,
          ),
        ),
        const SizedBox(height: 24),

        // --- Timeslot Configuration ---
        _buildSectionHeader(context, 'Reading Timeslots', Icons.access_time),
        ...timeslots.map((slot) => _buildTimeslotTile(context, slot)).toList(),
        ElevatedButton.icon(
          onPressed: () => _showAddTimeslotDialog(context),
          icon: const Icon(Icons.alarm_add_outlined),
          label: const Text('Add New Timeslot'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            foregroundColor: Theme.of(context).primaryColor,
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalTile(BuildContext context, VitalType vital) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        title: Text(vital.name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('Unit: ${vital.unit} | Normal: ${vital.normalRange}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
              onPressed: () => _showAddEditVitalDialog(context, vital: vital),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete(context, vital.id, vital.name, onDeleteVital),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeslotTile(BuildContext context, VitalTimeslot slot) {
    final formattedTime = MaterialLocalizations.of(context).formatTimeOfDay(slot.time);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        title: Text(slot.label, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(formattedTime),
        trailing: IconButton(
          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
          onPressed: () => _confirmDelete(context, slot.id, slot.label, onDeleteTimeslot),
        ),
      ),
    );
  }
  
  void _showAddEditVitalDialog(BuildContext context, {VitalType? vital}) {
    final isEditing = vital != null;
    final nameController = TextEditingController(text: vital?.name);
    final unitController = TextEditingController(text: vital?.unit);
    final rangeController = TextEditingController(text: vital?.normalRange);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Vital Sign' : 'Add New Vital Sign'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Vital Name (e.g., Blood Pressure)'),
                ),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: 'Unit (e.g., mmHg)'),
                ),
                TextField(
                  controller: rangeController,
                  decoration: const InputDecoration(labelText: 'Normal Range (e.g., 90-120/60-80)'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(isEditing ? 'Save' : 'Add'),
              onPressed: () {
                if (nameController.text.isNotEmpty && unitController.text.isNotEmpty) {
                  final newVital = VitalType(
                    // ID logic is handled by the parent state/database, but we need an ID for update
                    id: vital?.id ?? UniqueKey().toString(), 
                    name: nameController.text,
                    unit: unitController.text,
                    normalRange: rangeController.text.isEmpty ? 'N/A' : rangeController.text,
                  );
                  isEditing 
                      ? onUpdateVital(vital!.id, newVital) 
                      : onAddVital(newVital);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddTimeslotDialog(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      final labelController = TextEditingController(
        text: MaterialLocalizations.of(context).formatTimeOfDay(pickedTime),
      );

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Add New Timeslot'),
            content: TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Timeslot Label'),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Add'),
                onPressed: () {
                  if (labelController.text.isNotEmpty) {
                    final newSlot = VitalTimeslot(
                      id: UniqueKey().toString(),
                      label: labelController.text,
                      time: pickedTime,
                    );
                    onAddTimeslot(newSlot);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _confirmDelete(BuildContext context, String id, String name, Function(String) onDelete) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete "$name"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                onDelete(id);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}