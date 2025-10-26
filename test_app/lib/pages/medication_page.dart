import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../models/timeslot.dart';
import 'dart:math';

class MedicationPage extends StatefulWidget {
  @override
  _MedicationPageState createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  List<Medication> medications = [
    Medication(id: "1", name: "Lisinopril", dosage: "10mg", notes: "take with food", timeslotIds: ["0", "2"]),
    Medication(id: "2", name: "Vitamin D", dosage: "2000 IU", timeslotIds: ["1"]),
    Medication(id: "3", name: "Albuterol Inhaler", dosage: "2 puffs", timeslotIds: ["2"]),
  ];

  List<Timeslot> timeslots = [
    Timeslot(label: "Morning Medications", id: '0'),
    Timeslot(label: "Afternoon Medications", id: '1'),
    Timeslot(label: "Evening Medications", id: '2'),
  ];

  void _toggleTaken(String medId, String timeslotId) {
    setState(() {
      medications = medications.map((m) {
        if (m.id == medId) {
          final newMap = Map<String, bool>.from(m.isTakenByTimeslot);
          newMap[timeslotId] = !(newMap[timeslotId] ?? false);
          return m.copyWith(isTakenByTimeslot: newMap);
        }
        return m;
      }).toList();
    });
  }

  void _deleteMedication(String id) {
    setState(() {
      medications.removeWhere((m) => m.id == id);
    });
  }

  void _addMedication(Medication med) {
    setState(() {
      medications.add(med);
    });
  }

  void _editMedication(String id, String name, String dosage, String notes) {
    setState(() {
      Medication med = medications.singleWhere((m) => m.id == id);
      med.name = name;
      med.dosage = dosage;
      med.notes = notes;
    });
  }
  
  void _deleteTimeslot(String timeslotId) {
  setState(() {
    // Remove the timeslot from the list
    timeslots.removeWhere((ts) => ts.id == timeslotId);

    // Remove the timeslot from all medications
    medications = medications.map((m) {
      final newTimeslotIds = List<String>.from(m.timeslotIds)
        ..remove(timeslotId);

      // Also remove its taken status
      final newTakenMap = Map<String, bool>.from(m.isTakenByTimeslot)
        ..remove(timeslotId);

      return m.copyWith(
        timeslotIds: newTimeslotIds,
        isTakenByTimeslot: newTakenMap,
      );
    }).toList();
  });
  }


  void _addTimeslot(Timeslot slot, List<Medication> selectedMeds) {
    setState(() {
      timeslots.add(slot);

      // Update medications immutably
      medications = medications.map((m) {
        if (selectedMeds.contains(m)) {
          return m.copyWith(timeslotIds: [...m.timeslotIds, slot.id]);
        }
        return m;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Medication"),
          bottom: TabBar(
            tabs: [Tab(text: "Timeline"), Tab(text: "My Medications")],
          ),
        ),
        body: TabBarView(
          children: [
            MedicationTimelineScreen(
              medications: medications,
              timeslots: timeslots,
              toggleTaken: _toggleTaken,
              addTimeslot: _addTimeslot,
              deleteTimeslot: _deleteTimeslot,
            ),
            MyMedicationsScreen(
              medications: medications,
              timeslots: timeslots,
              deleteMedication: _deleteMedication, // pass the real function
              addMedication: _addMedication,       // also pass the real add function
              editMedication: _editMedication,
            ),
          ],
        ),
      ),
    );
  }
}


/// ---------------------
/// Timeline View
/// ---------------------
class MedicationTimelineScreen extends StatelessWidget {
  final List<Medication> medications;
  final List<Timeslot> timeslots;
  final void Function(String medId, String timeslotId) toggleTaken;
  final void Function(Timeslot slot, List<Medication> selectedMeds) addTimeslot;
  final void Function(String timeslotId) deleteTimeslot; 

  MedicationTimelineScreen({
    required this.medications,
    required this.timeslots,
    required this.toggleTaken,
    required this.addTimeslot,
    required this.deleteTimeslot,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        ...timeslots.map((slot) {
          final slotMeds =
              medications.where((m) => m.timeslotIds.contains(slot.id)).toList();
          return TimeslotCard(
            slot: slot,
            meds: slotMeds,
            timeslots: timeslots,
            toggleTaken: toggleTaken,
            deleteTimeslot: deleteTimeslot,
          );
        }),
        SizedBox(height: 12),
        ElevatedButton(
          child: Text("+ Add Timeslot"),
          onPressed: () {
            String newLabel = "";
            List<Medication> selectedMeds = [];

            showDialog(
              context: context,
              builder: (context) {
                return StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return AlertDialog(
                      title: Text("Add Timeslot"),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              decoration: InputDecoration(labelText: "Timeslot Name"),
                              onChanged: (val) => newLabel = val,
                            ),
                            SizedBox(height: 12),
                            Text("Assign to Medications:"),
                            Wrap(
                              spacing: 6,
                              children: medications.map((m) {
                                final isSelected = selectedMeds.contains(m);
                                return FilterChip(
                                  label: Text(
                                    m.name,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: Colors.blue,
                                  backgroundColor: Colors.grey.shade300,
                                  side: BorderSide(
                                    color: isSelected ? Colors.blue : Colors.grey,
                                  ),
                                  showCheckmark: false,
                                  onSelected: (selected) {
                                    setStateDialog(() {
                                      if (selected) {
                                        selectedMeds.add(m);
                                      } else {
                                        selectedMeds.remove(m);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (newLabel.isNotEmpty) {
                              final newSlot = Timeslot(
                                label: newLabel,
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                              );

                              addTimeslot(newSlot, selectedMeds);
                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "Added '${newSlot.label}' and assigned ${selectedMeds.length} medications."),
                                ),
                              );
                            }
                          },
                          child: Text("Save"),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}



class TimeslotCard extends StatelessWidget {
  final Timeslot slot;
  final List<Medication> meds;
  final List<Timeslot> timeslots;
  final void Function(String medId, String timeslotId) toggleTaken;
  final void Function(String timeslotId) deleteTimeslot;

  TimeslotCard({
    required this.slot,
    required this.meds,
    required this.timeslots,
    required this.toggleTaken,
    required this.deleteTimeslot,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(slot.label),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text("Delete Timeslot"),
                    content:
                        Text("Are you sure you want to delete '${slot.label}'?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          deleteTimeslot(slot.id);
                          Navigator.pop(ctx);
                        },
                        child: Text("Delete"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        children: meds
            .map((m) => CheckboxListTile(
                  title: Text("${m.name} ${m.dosage} \n Notes: ${m.notes}" ),
                  value: m.isTakenByTimeslot[slot.id] ?? false,
                  onChanged: (_) => toggleTaken(m.id, slot.id),
                  secondary: TextButton(
                    child: Text("Details"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MedicationDetailPage(
                            med: m,
                            timeslots: timeslots,
                          ),
                        ),
                      );
                    },
                  ),
                ))
            .toList(),
      ),
    );
  }
}


/// ---------------------
/// My Medications View
/// ---------------------
class MyMedicationsScreen extends StatefulWidget {
  final List<Medication> medications;
  final void Function(String id) deleteMedication;
  final void Function(Medication med) addMedication;
  final void Function(String id, String name, String dosage, String notes) editMedication;
  final List<Timeslot> timeslots;

  MyMedicationsScreen({
    required this.medications,
    required this.deleteMedication,
    required this.addMedication,
    required this.editMedication,
    required this.timeslots,
  });

  @override
  _MyMedicationsScreenState createState() => _MyMedicationsScreenState();
}

class _MyMedicationsScreenState extends State<MyMedicationsScreen> {
  List<Timeslot> selectedSlots = [];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        ...widget.medications.map((m) => Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text("${m.name} ${m.dosage} \n Notes: ${m.notes}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MedicationDetailPage(med: m, timeslots: widget.timeslots),
                          ),
                        );
                      },
                      child: Text("Details"),
                    ),
                    TextButton(
                      child: Text("Edit Medication"),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            String name = m.name;
                            String dosage = m.dosage;
                            String notes = m.notes;
                            List<Timeslot> tempSelectedSlots = [...selectedSlots];

                            return StatefulBuilder(
                              builder: (context, setStateDialog) {
                                return AlertDialog(
                                  title: Text("Edit Medication"),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          decoration: InputDecoration(labelText: "Name"),
                                          onChanged: (val) => name = val,
                                        ),
                                        TextField(
                                          decoration: InputDecoration(labelText: "Dosage"),
                                          onChanged: (val) => dosage = val,
                                        ),
                                        TextField(
                                          decoration: InputDecoration(labelText: "Notes"),
                                          onChanged: (val) => notes = val,
                                        ),
                                        SizedBox(height: 12),
                                        Text("Assign to Timeslots:"),
                                        Wrap(
                                          spacing: 6,
                                          children: widget.timeslots.map((slot) {
                                            final isSelected = tempSelectedSlots.contains(slot);
                                            return FilterChip(
                                              label: Text(
                                                slot.label,
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : Colors.black,
                                                ),
                                              ),
                                              selected: isSelected,
                                              selectedColor: Colors.blue,
                                              backgroundColor: Colors.grey.shade300,
                                              side: BorderSide(
                                                color: isSelected ? Colors.blue : Colors.grey,
                                              ),
                                              showCheckmark: false,
                                              onSelected: (selected) {
                                                setStateDialog(() {
                                                  if (selected) {
                                                    tempSelectedSlots.add(slot);
                                                  } else {
                                                    tempSelectedSlots.remove(slot);
                                                  }
                                                });
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text("Cancel")),
                                    ElevatedButton(
                                      onPressed: () {
                                        if (name.isNotEmpty &&
                                            dosage.isNotEmpty &&
                                            tempSelectedSlots.isNotEmpty) {
                                          widget.editMedication(m.id, name, dosage, notes);
                                          Navigator.pop(context);
                                          setState(() {
                                            selectedSlots = [];
                                          });
                                        }
                                      },
                                      child: Text("Save"),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text("Delete Medication"),
                            content: Text("Are you sure you want to delete '${m.name}'?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx), // Cancel
                                child: Text("Cancel"),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  widget.deleteMedication(m.id); // Delete
                                  Navigator.pop(ctx);
                                },
                                child: Text("Delete"),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(
                        "Delete",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            )),
        ElevatedButton(
          child: Text("+ Add Medication"),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                String name = "";
                String dosage = "";
                String notes = "";
                List<Timeslot> tempSelectedSlots = [...selectedSlots];

                return StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return AlertDialog(
                      title: Text("Add Medication"),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              decoration: InputDecoration(labelText: "Name"),
                              onChanged: (val) => name = val,
                            ),
                            TextField(
                              decoration: InputDecoration(labelText: "Dosage"),
                              onChanged: (val) => dosage = val,
                            ),
                            TextField(
                              decoration: InputDecoration(labelText: "Notes"),
                              onChanged: (val) => notes = val,
                            ),
                            SizedBox(height: 12),
                            Text("Assign to Timeslots:"),
                            Wrap(
                              spacing: 6,
                              children: widget.timeslots.map((slot) {
                                final isSelected = tempSelectedSlots.contains(slot);
                                return FilterChip(
                                  label: Text(
                                    slot.label,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: Colors.blue,
                                  backgroundColor: Colors.grey.shade300,
                                  side: BorderSide(
                                    color: isSelected ? Colors.blue : Colors.grey,
                                  ),
                                  showCheckmark: false,
                                  onSelected: (selected) {
                                    setStateDialog(() {
                                      if (selected) {
                                        tempSelectedSlots.add(slot);
                                      } else {
                                        tempSelectedSlots.remove(slot);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Cancel")),
                        ElevatedButton(
                          onPressed: () {
                            if (name.isNotEmpty &&
                                dosage.isNotEmpty &&
                                tempSelectedSlots.isNotEmpty) {
                              widget.addMedication(
                                Medication(
                                  id: Random().nextInt(9999).toString(),
                                  name: name,
                                  dosage: dosage,
                                  notes: notes,
                                  timeslotIds:
                                      tempSelectedSlots.map((s) => s.id).toList(),
                                ),
                              );
                              Navigator.pop(context);
                              setState(() {
                                selectedSlots = [];
                              });
                            }
                          },
                          child: Text("Save"),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// ---------------------
/// Medication Detail Page
/// ---------------------
class MedicationDetailPage extends StatelessWidget {
  final Medication med;
  final List<Timeslot> timeslots;

  MedicationDetailPage({required this.med, required this.timeslots});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(med.name)),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          ExpansionTile(
            initiallyExpanded: true,
            title: Text("Name: ${med.name}"),
            children: [
              ListTile(title: Text("Dosage: ${med.dosage}")),
              ListTile(title: Text("Notes: ${med.notes}")),
              ListTile(
                title: Text("Assigned Timeslots:"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: med.timeslotIds.map((id) {
                    final ts = timeslots.firstWhere(
                      (t) => t.id == id,
                      orElse: () => Timeslot(id: id, label: "Unknown"),
                    );
                    final taken = med.isTakenByTimeslot[id] ?? false;
                    return Text("${ts.label} — Taken: ${taken ? "Yes" : "No"}");
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}





