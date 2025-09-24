import 'package:flutter/material.dart';
import '../models/medication.dart';

class MedicationPage extends StatefulWidget {
  const MedicationPage({super.key});

  @override
  _MedicationPageState createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  List<Medication> medications = [
    Medication(
      id: '1',
      name: "Aspirin",
      dosage: "81mg",
      nextDose: DateTime.now().add(Duration(hours: 2)),
    ),
    Medication(
      id: '2',
      name: "Lisinopril",
      dosage: "10mg",
      nextDose: DateTime.now().add(Duration(hours: 6)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Medications"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addMedication,
          ),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: medications.length,
        itemBuilder: (context, index) {
          final med = medications[index];
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: med.isTaken ? Colors.green : Colors.orange,
                child: Icon(Icons.medication, color: Colors.white),
              ),
              title: Text(med.name),
              subtitle: Text("${med.dosage} - Next: ${med.nextDose.hour}:${med.nextDose.minute.toString().padLeft(2, '0')}"),
              trailing: med.isTaken 
                ? Icon(Icons.check_circle, color: Colors.green)
                : ElevatedButton(
                    onPressed: () => _takeMedication(index),
                    child: Text("Take"),
                  ),
            ),
          );
        },
      ),
    );
  }

  void _takeMedication(int index) {
    setState(() {
      medications[index] = medications[index].copyWith(isTaken: true);
    });
  }

  void _addMedication() {
    // TODO: Implement add medication dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Add medication feature coming soon!')),
    );
  }
}