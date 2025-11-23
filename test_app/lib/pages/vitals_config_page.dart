import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/vitals_data_models.dart';
import '../models/vital_timeslot.dart';

class VitalsConfigPage extends StatelessWidget {
  // Fix: Corrected type to VitalType
  final List<VitalType> configuredVitals;
  // Fix: Corrected type to VitalType
  final Function(VitalType vital) onAddVital;
  final Function(String id) onDeleteVital;
  // Fix: Corrected type to VitalType
  final Function(String id, VitalType updatedVital) onUpdateVital;
  final List<VitalTimeslot> timeslots;
  final Function(VitalTimeslot slot) onAddTimeslot;
  final Function(String id) onDeleteTimeslot;
  final Function(String id, VitalTimeslot slot) onUpdateTimeslot; // Added update timeslot

  const VitalsConfigPage({
    super.key,
    required this.configuredVitals,
    required this.onAddVital,
    required this.onDeleteVital,
    required this.onUpdateVital,
    required this.timeslots,
    required this.onAddTimeslot,
    required this.onDeleteTimeslot,
    required this.onUpdateTimeslot, // Added update timeslot
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // --- Vital Types Configuration ---
        _buildSectionHeader(context, 'Vital Signs to Track', Icons.monitor_heart),
        ...configuredVitals.map((vital) => _buildVitalTile(context, vital)).toList(),
        _buildAddButton(
          context: context,
          label: 'Add New Vital Sign',
          icon: Icons.add_box_outlined,
          onPressed: () => _showAddEditVitalDialog(context),
        ),
        
        const Divider(height: 32),

        // --- Timeslots Configuration ---
        _buildSectionHeader(context, 'Scheduled Timeslots', Icons.access_time),
        ...timeslots.map((slot) => _buildTimeslotTile(context, slot)).toList(),
        _buildAddButton(
          context: context,
          label: 'Add New Timeslot',
          icon: Icons.schedule,
          onPressed: () => _showAddEditTimeslotDialog(context),
        ),
      ],
    );
  }

  // Widget Builders
  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(40),
        ),
      ),
    );
  }

  Widget _buildVitalTile(BuildContext context, VitalType vital) {
    return Card(
      child: ListTile(
        title: Text(vital.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${vital.normalRange} (${vital.unit})'),
        trailing: Row(
          // FIX 3: Corrected the typo MainAxisSizeSize to MainAxisSize
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueGrey),
              onPressed: () => _showAddEditVitalDialog(context, vital),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(context, vital.id, vital.name, onDeleteVital),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeslotTile(BuildContext context, VitalTimeslot slot) {
    return Card(
      child: ListTile(
        title: Text(slot.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(slot.time.format(context)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueGrey),
              onPressed: () => _showAddEditTimeslotDialog(context, slot),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(context, slot.id, slot.label, onDeleteTimeslot),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialogs and Helpers ---

  // Helper for Vital Type Dialog
  void _showAddEditVitalDialog(BuildContext context, [VitalType? existingVital]) {
    final isEditing = existingVital != null;
    final nameController = TextEditingController(text: existingVital?.name ?? '');
    final rangeController = TextEditingController(text: existingVital?.normalRange ?? '');
    final unitController = TextEditingController(text: existingVital?.unit ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Vital Sign' : 'Add New Vital Sign'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Vital Name (e.g., Blood Pressure)')),
                TextField(controller: rangeController, decoration: const InputDecoration(labelText: 'Normal Range (e.g., 120/80)')),
                TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unit (e.g., mmHg, BPM, °F)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && rangeController.text.isNotEmpty && unitController.text.isNotEmpty) {
                  final newVital = VitalType(
                    id: isEditing ? existingVital!.id : const Uuid().v4(),
                    name: nameController.text,
                    normalRange: rangeController.text,
                    unit: unitController.text,
                  );
                  isEditing ? onUpdateVital(newVital.id, newVital) : onAddVital(newVital);
                  Navigator.pop(context);
                }
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );
  }

  // Helper for Timeslot Dialog
  void _showAddEditTimeslotDialog(BuildContext context, [VitalTimeslot? existingSlot]) {
    final isEditing = existingSlot != null;
    final labelController = TextEditingController(text: existingSlot?.label ?? '');
    TimeOfDay selectedTime = existingSlot?.time ?? TimeOfDay.now();

    // The time picker must be managed in a stateful way to update the dialog's UI.
    // Since VitalsConfigPage is StatelessWidget, we must use a StatefulWidget for the dialog content.
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> selectTime() async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: selectedTime,
              );
              if (picked != null && picked != selectedTime) {
                setState(() {
                  selectedTime = picked;
                });
              }
            }

            return AlertDialog(
              title: Text(isEditing ? 'Edit Timeslot' : 'Add New Timeslot'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: labelController, decoration: const InputDecoration(labelText: 'Timeslot Label (e.g., Dinner, Before Bed)')),
                    ListTile(
                      title: Text('Time: ${selectedTime.format(context)}'),
                      trailing: const Icon(Icons.edit),
                      onTap: selectTime,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (labelController.text.isNotEmpty) {
                      final newSlot = VitalTimeslot(
                        id: isEditing ? existingSlot!.id : const Uuid().v4(),
                        label: labelController.text,
                        time: selectedTime,
                      );
                      isEditing ? onUpdateTimeslot(newSlot.id, newSlot) : onAddTimeslot(newSlot);
                      Navigator.pop(context);
                    }
                  },
                  child: Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper for Delete Confirmation
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