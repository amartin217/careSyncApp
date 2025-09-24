import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: "Next Medication",
                    value: "2:00 PM",
                    icon: Icons.medication,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: "Last Vitals",
                    value: "Today",
                    icon: Icons.favorite,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildUpcomingSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Upcoming Today", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.local_hospital, color: Colors.blue),
              title: Text("Aspirin - 81mg"),
              subtitle: Text("2:00 PM"),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}