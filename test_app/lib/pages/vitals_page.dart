import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/vitals_data_models.dart';
import '../widgets/stat_card.dart';
import '../widgets/vitals_timeline_tab.dart'; 

class VitalsPage extends StatefulWidget {
  // Updated parameters to use the new models
  final List<VitalType> configuredVitals;
  final List<VitalReading> readings;
  final Function(VitalReading reading) addReading; // Function to add a reading

  // Fix: Constructor updated to accept configuredVitals and readings
  const VitalsPage({
    super.key,
    required this.configuredVitals,
    required this.readings,
    required this.addReading,
  });

  @override
  State<VitalsPage> createState() => _VitalsPageState();
}

class _VitalsPageState extends State<VitalsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Uuid uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    // Assuming 2 tabs: Summary and Timeline
    _tabController = TabController(length: 2, vsync: this); 
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Utility to get the latest reading for a specific VitalType
  VitalReading? _getLatestReading(String vitalId) {
    final readingsForVital = widget.readings.where((r) => r.vitalId == vitalId).toList();
    if (readingsForVital.isEmpty) return null;
    return readingsForVital.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
  }

  // Dialog to add a new vital reading
  Future<void> _showAddReadingDialog(VitalType vitalType) async {
    String? value;
    
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add ${vitalType.name} Reading'),
          content: TextField(
            keyboardType: vitalType.unit.contains('/') ? TextInputType.text : TextInputType.number, 
            decoration: InputDecoration(
              labelText: 'Value (e.g., ${vitalType.normalRange})',
              suffixText: vitalType.unit,
            ),
            onChanged: (v) => value = v,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                if (value != null && value!.isNotEmpty) {
                  final newReading = VitalReading(
                    id: uuid.v4(),
                    vitalId: vitalType.id, // Use the vitalType's ID
                    value: value!,
                    unit: vitalType.unit, // Use the vitalType's unit
                    timestamp: DateTime.now(),
                  );
                  widget.addReading(newReading); // Call the addReading function
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitals Tracker'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Timeline'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Summary Tab
          _buildSummaryTab(),
          // Timeline Tab
          _buildTimelineTab(), 
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest Readings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Check if any vitals are configured
          if (widget.configuredVitals.isEmpty) 
            const Center(child: Text("Please configure vital signs in the Config tab.")),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 1.0, 
            ),
            itemCount: widget.configuredVitals.length,
            itemBuilder: (context, index) {
              final vital = widget.configuredVitals[index];
              final latestReading = _getLatestReading(vital.id);
              
              // Simple icon mapping 
              IconData icon;
              if (vital.name.contains('Heart')) {
                icon = Icons.favorite;
              } else if (vital.name.contains('Pressure')) {
                icon = Icons.monitor_heart;
              } else if (vital.name.contains('Temp')) {
                icon = Icons.thermostat;
              } else {
                icon = Icons.auto_graph;
              }

              return InkWell(
                onTap: () => _showAddReadingDialog(vital),
                child: StatCard(
                  title: vital.name,
                  value: latestReading != null 
                      ? '${latestReading.value} ${latestReading.unit}' 
                      : 'N/A',
                  icon: icon,
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    // Pass the complete list of all readings to the timeline view
    return VitalsTimelineTab(
      readings: widget.readings, 
      // Need to pass the configured vitals to look up the name from the ID
      configuredVitals: widget.configuredVitals, 
    );
  }
}