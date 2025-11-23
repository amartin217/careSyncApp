import 'package:flutter/material.dart';
import '../models/vitals_data_models.dart'; 

class VitalsTimelineTab extends StatelessWidget {
  final List<VitalReading> readings; 
  // Added configuredVitals to look up the name of the vital from its ID
  final List<VitalType> configuredVitals; 

  const VitalsTimelineTab({
    super.key, 
    required this.readings,
    required this.configuredVitals,
  }); 
  
  // Helper to find the VitalType name by ID
  String _getVitalName(String vitalId) {
    return configuredVitals.firstWhere(
      (v) => v.id == vitalId, 
      orElse: () => VitalType(id: vitalId, name: 'Unknown Vital', normalRange: 'N/A', unit: ''),
    ).name;
  }

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(child: Text("No vital readings recorded yet."));
    }
    
    // Sort readings by date in descending order
    final sortedReadings = List<VitalReading>.from(readings)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      itemCount: sortedReadings.length,
      itemBuilder: (context, index) {
        final reading = sortedReadings[index];
        final vitalName = _getVitalName(reading.vitalId); // Get the display name

        // Formatting the timestamp for display
        final timeString = 
            '${reading.timestamp.hour}:${reading.timestamp.minute.toString().padLeft(2, '0')}';
        final dateString = 
            '${reading.timestamp.month}/${reading.timestamp.day}/${reading.timestamp.year}';

        return Card(
          child: ListTile(
            leading: const Icon(Icons.history, color: Colors.blueGrey),
            title: Text('${reading.value} ${reading.unit}', 
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Recorded $vitalName at $timeString on $dateString'), // Display vital name here
            trailing: Text(vitalName), // Use the full vital name here as well for emphasis
          ),
        );
      },
    );
  }
}