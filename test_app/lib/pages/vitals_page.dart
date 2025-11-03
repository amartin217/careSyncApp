import 'package:flutter/material.dart';
import '../models/vital.dart';
import '../models/vital_timeslot.dart';
import '../models/vital_reading.dart';
import '../widgets/latest_vital_card.dart';

// --- Vitals Page ---
// This page now receives all its data and handlers from VitalsScreen in main.dart
class VitalsPage extends StatelessWidget {
  // Data for the Latest Readings view
  final List<Map<String, dynamic>> vitalData;
  // All vitals (for the log dialog)
  final List<Vital> vitals;
  // All timeslots (for the log dialog)
  final List<VitalTimeslot> timeslots;
  // Handler to add a new reading
  final void Function(VitalReading reading) addReading;
  // Handler to add a new timeslot
  final void Function(VitalTimeslot slot) addTimeslot;

  const VitalsPage({
    super.key,
    required this.vitalData,
    required this.vitals,
    required this.timeslots,
    required this.addReading,
    required this.addTimeslot,
  });

  // Helper to show a dialog for logging a new reading
  Future<void> _showLogReadingDialog(BuildContext context) async {
    String? selectedVitalId;
    String? selectedTimeslotId;
    final TextEditingController valueController = TextEditingController();
    final TextEditingController systolicController = TextEditingController();
    final TextEditingController diastolicController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // FIX 2: Added 'unit' to the Vital fallback constructor.
            final selectedVital = vitals.firstWhere(
              (v) => v.id == selectedVitalId,
              orElse: () => vitals.isEmpty 
                  ? Vital(id: 'none', name: 'N/A', normalRange: '', unit: '', icon: Icons.error, iconColor: Colors.grey) 
                  : vitals.first,
            );
            
            // Default to the first vital if none is selected
            if (selectedVitalId == null && vitals.isNotEmpty) {
                selectedVitalId = vitals.first.id;
            }

            return AlertDialog(
              title: const Text('Log New Vital Reading'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Vital Type Dropdown
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Vital Type'),
                      value: selectedVitalId,
                      items: vitals.map((vital) {
                        return DropdownMenuItem(
                          value: vital.id,
                          child: Text(vital.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedVitalId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // 2. Timeslot Dropdown
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Time Slot'),
                      value: selectedTimeslotId,
                      items: timeslots.map((slot) {
                        return DropdownMenuItem(
                          value: slot.id,
                          child: Text(slot.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedTimeslotId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // 3. Value Input (Conditional for BP)
                    if (selectedVital.name == 'Blood Pressure') ...[
                      TextField(
                        controller: systolicController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Systolic (Top Number)'),
                      ),
                      TextField(
                        controller: diastolicController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Diastolic (Bottom Number)'),
                      ),
                    ] else ...[
                      TextField(
                        controller: valueController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Value (${selectedVital.name})'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validation and Reading Creation
                    if (selectedVitalId == null || selectedTimeslotId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select vital type and time slot.')),
                      );
                      return;
                    }
                    
                    if (selectedVital.name == 'Blood Pressure') {
                      final sys = int.tryParse(systolicController.text);
                      final dias = int.tryParse(diastolicController.text);
                      if (sys == null || dias == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter valid Systolic/Diastolic values.')),
                        );
                        return;
                      }

                      // Create Blood Pressure reading
                      final newReading = VitalReading(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        vitalId: selectedVitalId!,
                        value: sys.toDouble(), // Use systolic as the main value for simplicity
                        timestamp: DateTime.now(),
                        unit: selectedVital.unit,
                        systolic: sys,
                        diastolic: dias,
                      );
                      addReading(newReading);
                      
                    } else {
                      final val = double.tryParse(valueController.text);
                      if (val == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid vital value.')),
                        );
                        return;
                      }

                      // Create standard reading
                      final newReading = VitalReading(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        vitalId: selectedVitalId!,
                        value: val,
                        timestamp: DateTime.now(),
                        unit: selectedVital.unit,
                      );
                      addReading(newReading);
                    }
                    
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vital reading logged!')),
                    );

                  },
                  child: const Text('Log Reading'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper to show a toast message (since the configuration is now on the next tab)
  void _onVitalCardTap(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tapped on $title. Use the "Configuration" tab to edit details.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header section (Latest Readings)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
              child: Text(
                'Latest Readings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // List of Latest Vital Cards
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final vital = vitalData[index];
                return LatestVitalCard(
                  title: vital['title'] as String,
                  normalRange: vital['normalRange'] as String,
                  currentValue: vital['currentValue'] as String,
                  unit: vital['unit'] as String,
                  timeAgo: vital['timeAgo'] as String,
                  icon: vital['icon'] as IconData,
                  iconColor: vital['iconColor'] as Color,
                  onTap: () => _onVitalCardTap(context, vital['title'] as String),
                );
              },
              childCount: vitalData.length,
            ),
          ),
          
          const SliverToBoxAdapter(
            child: SizedBox(height: 100), // Padding for FAB
          ),
        ],
      ),

      // Floating Action Button to Log a New Reading
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogReadingDialog(context),
        label: const Text(
          'Log New Reading',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
