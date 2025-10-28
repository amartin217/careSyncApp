import 'package:flutter/material.dart';
import '../widgets/latest_vital_card.dart';

class VitalsPage extends StatelessWidget {
  const VitalsPage({super.key});

  // Placeholder data mimicking the latest readings
  static const List<Map<String, dynamic>> _latestVitals = [
    {
      'title': 'Blood Pressure',
      'normalRange': '120/80',
      'currentValue': '128/82',
      'unit': 'mmHg',
      'timeAgo': '2 hours ago',
      'icon': Icons.favorite_border,
      'iconColor': Color(0xFF673AB7), // Deep Purple
    },
    {
      'title': 'Heart Rate',
      'normalRange': '60-100',
      'currentValue': '72',
      'unit': 'bpm',
      'timeAgo': '2 hours ago',
      'icon': Icons.show_chart,
      'iconColor': Color(0xFFF44336), // Red
    },
    {
      'title': 'Temperature',
      'normalRange': '98.6',
      'currentValue': '98.6',
      'unit': '°F',
      'timeAgo': 'This morning',
      'icon': Icons.thermostat_outlined,
      'iconColor': Color(0xFFFF9800), // Orange
    },
    {
      'title': 'Blood Glucose',
      'normalRange': '70-130',
      'currentValue': '110',
      'unit': 'mg/dL',
      'timeAgo': 'Yesterday',
      'icon': Icons.bloodtype,
      'iconColor': Color(0xFF4CAF50), // Green
    },
  ];

  void _navigateToLogVitals(BuildContext context) {
    // This function will navigate the user to the form screen 
    // where they input new readings.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigating to Log Vitals screen...')),
    );
    // In a real app: Navigator.of(context).push(MaterialPageRoute(builder: (context) => LogVitalsScreen()));
  }

  void _onVitalCardTap(BuildContext context, String vitalTitle) {
    // This function will navigate the user to a historical chart/detail screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing history for $vitalTitle')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Vitals",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
            onPressed: () => _navigateToLogVitals(context),
            tooltip: 'Log New Vital',
          ),
        ],
        elevation: 0,
      ),
      
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text(
                "Track health measurements",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final vital = _latestVitals[index];
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
              childCount: _latestVitals.length,
            ),
          ),
        ],
      ),

      // Floating Action Button matching the functionality of the "Add Reading" button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToLogVitals(context),
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