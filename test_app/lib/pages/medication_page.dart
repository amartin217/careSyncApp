import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../models/timeslot.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../widgets/profile_menu.dart';


class MedicationPage extends StatefulWidget {
  @override
  _MedicationPageState createState() => _MedicationPageState();
}


class _MedicationPageState extends State<MedicationPage> {
  final Map<String, Color> medColors = {}; // maps med.id -> color

  final List<Color> colors = [
    Colors.blue.shade100,
    Colors.red.shade100,
    Colors.green.shade100,
    Colors.yellow.shade100,
    Colors.purple.shade100,
    Colors.pink.shade100,
    Colors.indigo.shade100,
    Colors.lightBlue.shade100,
    Colors.deepOrange.shade100,
    Colors.cyan.shade100,
    Colors.orange.shade100,
    Colors.teal.shade100,
    Colors.lime.shade100,
    Colors.grey.shade300,
    Colors.blueGrey.shade200,
  ];

  Color _getMedColor(String medId) {
    if (!medColors.containsKey(medId)) {
      final index = medColors.length % colors.length; // sequential assignment
      medColors[medId] = colors[index];
    }
    return medColors[medId]!;
  }

  List<Medication> medications = [];

  List<Timeslot> timeslots = [];

  final supabase = Supabase.instance.client;

  Future<void> _loadData() async {
    final supabase = Supabase.instance.client;
    final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD

    // 1️⃣ Determine patient ID
    final userId = supabase.auth.currentUser!.id;

    // Get patient linked to caregiver, or use self if patient
    final careRelation = await supabase
        .from('CareRelation')
        .select('patient_id')
        .eq('user_id', userId);

    final patientId = (careRelation as List).isNotEmpty
        ? careRelation.first['patient_id'] as String
        : userId;

    // 2️⃣ Fetch medications for this patient
    final medData = await supabase
        .from('Medication')
        .select()
        .eq('patient_id', patientId) as List<dynamic>;

    // 3️⃣ Fetch timeslots for this patient
    final timeData = await supabase
        .from('Timeslot')
        .select()
        .eq('patient_id', patientId) as List<dynamic>;

    // 4️⃣ Fetch today's medication logs for this patient
    final logData = await supabase
        .from('MedicationLog')
        .select()
        .eq('patient_id', patientId)
        .eq('date', today) as List<dynamic>;

    setState(() {
      // Map timeslots
      timeslots = timeData.map((t) {
        final timeParts = (t['time'] as String).split(':'); // "HH:mm"
        return Timeslot(
          id: t['id'] as String,
          label: t['label'] as String,
          time: TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          ),
        );
      }).toList();

      // Map medications with timeslots and today's logs
      medications = medData.map((m) {
        final List<String> timeslotIds =
            (m['timeslot_ids'] as List<dynamic>?)?.cast<String>() ?? [];

        // Build map of timeslot_id -> isTaken for this med
        final isTakenByTimeslot = <String, bool>{};
        for (final tsId in timeslotIds) {
          final log = logData.firstWhere(
            (l) => l['medication_id'] == m['id'] && l['timeslot_id'] == tsId,
            orElse: () => <String, dynamic>{}, // return an empty map instead of null
          );
          isTakenByTimeslot[tsId] = log.isNotEmpty ? (log['is_taken'] as bool? ?? false) : false;
        }

        return Medication(
          id: m['id'] as String,
          name: m['name'] as String,
          dosage: m['dosage'] as String,
          notes: m['notes'] as String? ?? '',
          timeslotIds: timeslotIds,
          isTakenByTimeslot: isTakenByTimeslot,
        );
      }).toList();
    });
  }



  


  Future<void> _toggleTaken(String medId, String timeslotId) async {
    final supabase = Supabase.instance.client;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final medIndex = medications.indexWhere((m) => m.id == medId);
    if (medIndex == -1) return;
  
    final med = medications[medIndex];
    final newValue = !(med.isTakenByTimeslot[timeslotId] ?? false);
    final userId = supabase.auth.currentUser!.id;
  
    // Get patient_id
    final careRelation = await supabase
        .from('CareRelation')
        .select('patient_id')
        .eq('user_id', userId);
  
    final patientId = (careRelation as List).isNotEmpty
        ? careRelation.first['patient_id'] as String
        : userId;
  
    try {
      // ✅ upsert to Supabase
      await supabase.from('MedicationLog').upsert({
        'medication_id': medId,
        'timeslot_id': timeslotId,
        'date': today,
        'is_taken': newValue,
        'taken_at': DateTime.now().toIso8601String(),
        'recorder_id': userId,
        'patient_id': patientId,
      }, onConflict: 'medication_id,timeslot_id,date');
  
      // ✅ update local state immutably
      setState(() {
        final updatedMed = med.copyWith(
          isTakenByTimeslot: {
            ...med.isTakenByTimeslot,
            timeslotId: newValue,
          },
        );
  
        medications = [
          ...medications.take(medIndex),
          updatedMed,
          ...medications.skip(medIndex + 1),
        ];
      });
  
      debugPrint('✅ Toggled med=$medId, slot=$timeslotId → $newValue');
    } catch (e) {
      debugPrint('❌ Failed to toggle medication $medId: $e');
    }
  }

  
  

  Future<void> _deleteMedication(String id) async {
    final supabase = Supabase.instance.client;

    await supabase.from('Medication').delete().eq('id', id);
    await supabase.from('MedicationLog').delete().eq('medication_id', id);

    setState(() {
      medications.removeWhere((m) => m.id == id);
    });
  }


  Future<void> _addMedication(Medication med) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;
    final careRelation = await supabase
        .from('CareRelation')
        .select('patient_id')
        .eq('user_id', userId);

    final patientId = (careRelation as List).isNotEmpty
        ? careRelation.first['patient_id'] as String
        : userId;

    await supabase.from('Medication').insert({
      'id': med.id,
      'patient_id': patientId,
      'name': med.name,
      'dosage': med.dosage,
      'notes': med.notes,
      'timeslot_ids': med.timeslotIds,
    });

    setState(() {
      medications.add(med);
    });
  }


  Future<void> _editMedication(String id, String name,  String dosage,  String notes, List<Timeslot> timeslotsForMed) async {
    final supabase = Supabase.instance.client;

    // Convert List<Timeslot> -> List<String> (timeslot IDs)
    final timeslotIds = timeslotsForMed.map((t) => t.id).toList();

    try {
      await supabase.from('Medication').update({
        'name': name,
        'dosage': dosage,
        'notes': notes,
        'timeslot_ids': timeslotIds, // ← this must match your column name in Supabase
      }).eq('id', id);

      debugPrint('✅ Updated Medication $id with timeslotIds: $timeslotIds');
    } catch (e) {
      debugPrint('❌ Failed to update Medication $id: $e');
    }

    // Optionally: also update local state if necessary
    setState(() {
      medications = medications.map((m) {
        if (m.id == id) {
          return m.copyWith(timeslotIds: timeslotIds);
        }
        return m;
      }).toList();
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


  Future<void> _addTimeslot(Timeslot slot, List<Medication> selectedMeds) async {
  final supabase = Supabase.instance.client;

  try {
    // 1️⃣ Determine patient ID
    final userId = supabase.auth.currentUser!.id;
    final careRelation = await supabase
        .from('CareRelation')
        .select('patient_id')
        .eq('user_id', userId);

    final patientId = (careRelation as List).isNotEmpty
        ? careRelation.first['patient_id'] as String
        : userId;

    // 2️⃣ Insert timeslot into Supabase
    await supabase.from('Timeslot').insert({
      'id': slot.id,
      'label': slot.label,
      'time': '${slot.time.hour.toString().padLeft(2, '0')}:${slot.time.minute.toString().padLeft(2, '0')}',
      'patient_id': patientId,
    });

    // 3️⃣ Create medication_log entries for each linked medication (for today)
    final today = DateTime.now().toIso8601String().split('T')[0];
    for (final med in selectedMeds) {
      await supabase.from('medication_log').insert({
        'id': med.id, // or generate new UUID if your log table uses unique IDs
        'patient_id': patientId,
        'recorder_id': supabase.auth.currentUser!.id,
        'medication_id': med.id,
        'timeslot_id': slot.id,
        'date': today,
        'is_taken': false,
      });
    }

    // 4️⃣ Update local state for UI
    setState(() {
      timeslots.add(slot);

      medications = medications.map((m) {
        if (selectedMeds.contains(m)) {
          return m.copyWith(timeslotIds: [...m.timeslotIds, slot.id]);
        }
        return m;
      }).toList();
    });
  } catch (e) {
    debugPrint('Error adding timeslot: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error adding timeslot: $e')),
    );
  }
}


  Future<void> _editTimeslot(String id, String label, TimeOfDay time, List<Medication> selectedMeds) async {
    final supabase = Supabase.instance.client;
  
    try {
      // 1️⃣ Update Timeslot in Supabase
      await supabase.from('Timeslot').update({
        'label': label,
        'time': '${time.hour}:${time.minute}',
      }).eq('id', id);
  
      debugPrint('✅ Timeslot $id updated in Supabase');
  
      // 2️⃣ Update local state
      setState(() {
        // Update only the changed fields
        timeslots = timeslots.map((slot) {
          if (slot.id == id) {
            return slot.copyWith(
              label: label,
              time: time,
            );
          }
          return slot;
        }).toList();
  
        // 3️⃣ Update medications immutably
        final editedSlot = timeslots.firstWhere(
          (t) => t.id == id,
          orElse: () => Timeslot(id: id, label: label, time: time),
        );
  
        medications = medications.map((m) {
          final isSelected = selectedMeds.contains(m);
          final hasSlot = m.timeslotIds.contains(id);
  
          if (isSelected && !hasSlot) {
            final newSlotObjects = [
              ...m.timeslotIds.map((tid) => timeslots.firstWhere(
                    (t) => t.id == tid,
                    orElse: () => Timeslot(id: tid, label: "Unknown", time: TimeOfDay.now()),
                  )),
              editedSlot,
            ];

            _editMedication(m.id, m.name, m.dosage, m.notes, newSlotObjects);
  
            return m.copyWith(timeslotIds: [...m.timeslotIds, id]);
          } else if (!isSelected && hasSlot) {
            final remainingIds = m.timeslotIds.where((tid) => tid != id).toList();
            final newSlotObjects = remainingIds.map((tid) => timeslots.firstWhere(
                  (t) => t.id == tid,
                  orElse: () => Timeslot(id: tid, label: "Unknown", time: TimeOfDay.now()),
                )).toList();
  
            _editMedication(m.id, m.name, m.dosage, m.notes, newSlotObjects);
  
            return m.copyWith(timeslotIds: remainingIds);
          }
          return m;
        }).toList();
      });
  
      debugPrint('✅ Timeslot $id updated in UI');
    } catch (e, stack) {
      debugPrint('❌ Supabase update failed: $e');
      debugPrint(stack.toString());
    }
  }



  @override
  void initState() {
    super.initState();
    _loadData();
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
          actions: const [
            ProfileMenuButton(),
          ],
        ),
        body: TabBarView(
          children: [
            MedicationTimelineScreen(
              medications: medications,
              timeslots: timeslots,
              toggleTaken: _toggleTaken,
              addTimeslot: _addTimeslot,
              deleteTimeslot: _deleteTimeslot,
              editTimeslot: _editTimeslot,
              getMedColor: _getMedColor,
            ),
            MyMedicationsScreen(
              medications: medications,
              timeslots: timeslots,
              deleteMedication: _deleteMedication, // pass the real function
              addMedication: _addMedication,       // also pass the real add function
              editMedication: _editMedication,
              getMedColor: _getMedColor,
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
  final void Function(String id, String label, TimeOfDay time, List<Medication> selectedMeds) editTimeslot;
  final Color Function(String medId) getMedColor;

  MedicationTimelineScreen({
    required this.medications,
    required this.timeslots,
    required this.toggleTaken,
    required this.addTimeslot,
    required this.deleteTimeslot,
    required this.editTimeslot,
    required this.getMedColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
  ...(
    timeslots.toList()
      ..sort((a, b) {
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      })
  ).map((slot) {
    final slotMeds = medications
        .where((m) => m.timeslotIds.contains(slot.id))
        .toList();

    return TimeslotCard(
      slot: slot,
      meds: slotMeds,
      timeslots: timeslots,
      toggleTaken: toggleTaken,
      deleteTimeslot: deleteTimeslot,
      editTimeslot: editTimeslot,
      medicationTimelineScreenPointer: this,
      getMedColor: getMedColor,
    );
  }).toList(),

        SizedBox(height: 12),
        ElevatedButton(
        child: Text("+ Add Timeslot"),
        onPressed: () {
          String newLabel = "";
          TimeOfDay selectedTime = TimeOfDay.now();
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Name input field
                        TextField(
                          decoration: const InputDecoration(
                            labelText: "Timeslot Name",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => newLabel = val,
                        ),
                        const SizedBox(height: 16),

                        // Time picker field
                        GestureDetector(
                          onTap: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                              initialEntryMode: TimePickerEntryMode.input,
                            );
                            if (picked != null) {
                              setStateDialog(() {
                                selectedTime = picked;
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: "Timeslot Time",
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.access_time),
                              ),
                              controller: TextEditingController(
                                text: selectedTime.format(context),
                              ),
                              readOnly: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Medication chips
                        const Text(
                          "Assign to Medications:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
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
                              id: const Uuid().v4(),
                              time: selectedTime,
                            );

                            addTimeslot(newSlot, selectedMeds);
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Added '${newSlot.label}' at '${newSlot.time.format(context)}' and assigned ${selectedMeds.length} medications.",
                                ),
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
  final void Function(String id, String label, TimeOfDay time, List<Medication> selectedMeds) editTimeslot;
  final MedicationTimelineScreen medicationTimelineScreenPointer;
  final Color Function(String medId) getMedColor;


  TimeslotCard({
    required this.slot,
    required this.meds,
    required this.timeslots,
    required this.toggleTaken,
    required this.deleteTimeslot,
    required this.editTimeslot,
    required this.medicationTimelineScreenPointer,
    required this.getMedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        key: PageStorageKey(slot.id),
        maintainState: true,
        initiallyExpanded: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // left side: name + time
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  slot.time.format(context),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            // right side: icons
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    // existing edit dialog logic here
                    String editedLabel = slot.label;
                    TimeOfDay editedTime = slot.time;
                    List<Medication> selectedMeds = [];
                    for (Medication med in meds) {
                      if (med.timeslotIds.contains(slot.id)) {
                        selectedMeds.add(med);
                      }
                    }
                    showDialog(
                      context: context,
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (context, setStateDialog) {
                            return AlertDialog(
                              title: const Text("Edit Timeslot"),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      decoration: const InputDecoration(
                                        labelText: "Timeslot Name",
                                      ),
                                      controller: TextEditingController(
                                          text: editedLabel),
                                      onChanged: (val) => editedLabel = val,
                                    ),
                                    const SizedBox(height: 16),
                                    GestureDetector(
                                      onTap: () async {
                                        final TimeOfDay? picked =
                                            await showTimePicker(
                                          context: context,
                                          initialTime: editedTime,
                                          initialEntryMode:
                                              TimePickerEntryMode.input,
                                        );
                                        if (picked != null) {
                                          setStateDialog(() {
                                            editedTime = picked;
                                          });
                                        }
                                      },
                                      child: AbsorbPointer(
                                        child: TextField(
                                          decoration: const InputDecoration(
                                            labelText: "Timeslot Time",
                                            border: OutlineInputBorder(),
                                            suffixIcon:
                                                Icon(Icons.access_time),
                                          ),
                                          controller: TextEditingController(
                                            text: editedTime.format(context),
                                          ),
                                          readOnly: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text("Assigned Medications:"),
                                    Wrap(
                                      spacing: 6,
                                      children: medicationTimelineScreenPointer
                                          .medications
                                          .map((m) {
                                        final isSelected =
                                            selectedMeds.contains(m);
                                        return FilterChip(
                                          label: Text(
                                            m.name,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                          selected: isSelected,
                                          selectedColor: Colors.blue,
                                          backgroundColor:
                                              Colors.grey.shade100,
                                          side: BorderSide(
                                            color: isSelected
                                                ? Colors.blue
                                                : Colors.grey,
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
                                  onPressed: () =>
                                      Navigator.pop(context),
                                  child: const Text("Cancel"),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (editedLabel.isNotEmpty) {
                                      editTimeslot(
                                        slot.id,
                                        editedLabel,
                                        editedTime,
                                        selectedMeds,
                                      );
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: const Text("Save Changes"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Delete Timeslot"),
                        content: Text(
                            "Are you sure you want to delete '${slot.label}'?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              deleteTimeslot(slot.id);
                              Navigator.pop(ctx);
                            },
                            child: const Text("Delete"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        children: meds.map((m) {
          final medColor = getMedColor(m.id);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: medColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: medColor, width: 1.5),
              // boxShadow: [
              //   BoxShadow(
              //     color: Colors.black26,
              //     blurRadius: 3,
              //     offset: Offset(1, 2),
              //   ),
              // ],
            ),
            child: CheckboxListTile(
              title: Text(
                "${m.name} - ${m.dosage}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("Notes: ${m.notes}"),
              value: m.isTakenByTimeslot[slot.id] ?? false,
              onChanged: (_) => toggleTaken(m.id, slot.id),
              secondary: IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.black54),
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
            ),
          );
        }).toList(),
      )
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
  final void Function(String id, String name, String dosage, String notes, List<Timeslot> tempSelectedSlots) editMedication;
  final List<Timeslot> timeslots;
  final Color Function(String medId) getMedColor;

  MyMedicationsScreen({
    required this.medications,
    required this.deleteMedication,
    required this.addMedication,
    required this.editMedication,
    required this.timeslots,
    required this.getMedColor,
  });

  @override
  _MyMedicationsScreenState createState() => _MyMedicationsScreenState();
}

class _MyMedicationsScreenState extends State<MyMedicationsScreen> {
  List<Timeslot> selectedSlots = [];

  @override
  @override
Widget build(BuildContext context) {
  return ListView(
    padding: EdgeInsets.all(16),
    children: [
      ...widget.medications.map((m) {
        final medColor = widget.getMedColor(m.id);
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color:  medColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: medColor, width: 1.5),
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black26,
            //     blurRadius: 3,
            //     offset: Offset(1, 2),
            //   ),
            // ],
          ),
          child: ListTile(
            title: Text(
              "${m.name} ${m.dosage}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("Notes: ${m.notes}"),
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
                  child: Text("Edit"),
                  onPressed: () {
                    List<Timeslot> tempSelectedSlots = widget.timeslots
                     .where((ts) => m.timeslotIds.contains(ts.id))
                     .toList();
                    showDialog(
                      context: context,
                      builder: (context) {
                        String name = m.name;
                        String dosage = m.dosage;
                        String notes = m.notes;

                        return StatefulBuilder(
                          builder: (context, setStateDialog) {
                            final TextEditingController nameController =
                                TextEditingController(text: m.name);
                            final TextEditingController dosageController =
                                TextEditingController(text: m.dosage);
                            final TextEditingController notesController =
                                TextEditingController(text: m.notes);

                            return AlertDialog(
                              title: const Text("Edit Medication"),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: nameController,
                                      decoration: InputDecoration(labelText: "Name"),
                                      onChanged: (val) => name = val,
                                    ),
                                    TextField(
                                      controller: dosageController,
                                      decoration: InputDecoration(labelText: "Dosage"),
                                      onChanged: (val) => dosage = val,
                                    ),
                                    TextField(
                                      controller: notesController,
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
                                            slot.label + " " + slot.time.format(context),
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
                                    final updatedName = nameController.text.trim();
                                    final updatedDosage = dosageController.text.trim();
                                    final updatedNotes = notesController.text.trim();
                                    if (updatedName.isNotEmpty) {
                                      widget.editMedication(
                                        m.id,
                                        updatedName,
                                        updatedDosage,
                                        updatedNotes,
                                        tempSelectedSlots,
                                      );
                                      Navigator.pop(context);
                                      setState(() {
                                        tempSelectedSlots = [];
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
                            onPressed: () => Navigator.pop(ctx),
                            child: Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              widget.deleteMedication(m.id);
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
        );
      }).toList(),

      ElevatedButton(
        child: Text("+ Add Medication"),
        onPressed: () {
          String name = "";
          String dosage = "";
          String notes = "";
          List<Timeslot> tempSelectedSlots = [];

          showDialog(
            context: context,
            builder: (context) {
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
                                id: const Uuid().v4(),
                                name: name,
                                dosage: dosage,
                                notes: notes,
                                timeslotIds: tempSelectedSlots.map((s) => s.id).toList(),
                              ),
                            );
                            Navigator.pop(context);
                            setState(() {
                              tempSelectedSlots = [];
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
                      orElse: () => Timeslot(id: id, label: "Unknown", time: TimeOfDay.now()),
                    );
                    final taken = med.isTakenByTimeslot[id] ?? false;
                    String formattedTime = MaterialLocalizations.of(context).formatTimeOfDay(ts.time);
                    return Text("${ts.label}($formattedTime) — Taken: ${taken ? "Yes" : "No"}");
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





