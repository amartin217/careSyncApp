import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/vital.dart';
import '../models/timeslot.dart';
import '../models/vital_log.dart';
import '../widgets/profile_menu.dart';

class VitalsPage extends StatefulWidget {
  @override
  _VitalsPageState createState() => _VitalsPageState();
}

class _VitalsPageState extends State<VitalsPage> {
  final supabase = Supabase.instance.client;

  final Map<String, Color> vitalColors = {};
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

  Color _getVitalColor(String vitalId) {
    if (!vitalColors.containsKey(vitalId)) {
      final index = vitalColors.length % colors.length;
      vitalColors[vitalId] = colors[index];
    }
    return vitalColors[vitalId]!;
  }

  List<Vital> vitals = [];
  List<Timeslot> timeslots = [];

  /// latestLogs[vitalId]?[timeslotId] = VitalLog
  Map<String, Map<String, VitalLog>> latestLogs = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String> _resolvePatientId() async {
    final userId = supabase.auth.currentUser!.id;

    final careRelation = await supabase
        .from('CareRelation')
        .select('patient_id')
        .eq('user_id', userId);

    final patientId = (careRelation as List).isNotEmpty
        ? careRelation.first['patient_id'] as String
        : userId;

    return patientId;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final patientId = await _resolvePatientId();

      // Fetch timeslots
      final timeData = await supabase
          .from('VitalTimeslot')
          .select()
          .eq('patient_id', patientId) as List<dynamic>;

      final loadedTimeslots = timeData.map((t) {
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

      // Fetch vitals
      final vitalData = await supabase
          .from('Vital')
          .select()
          .eq('patient_id', patientId) as List<dynamic>;

      final loadedVitals = vitalData.map<Vital>((v) => Vital.fromJson(v)).toList();

      // Fetch today's logs for these vitals
      Map<String, Map<String, VitalLog>> latest = {};
      if (loadedVitals.isNotEmpty) {
        final vitalIds = loadedVitals.map((v) => v.id).toList();
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));

        final logData = await supabase
            .from('VitalLog')
            .select()
            .inFilter('vital_id', vitalIds)
            .gte('datetime', start.toIso8601String())
            .lt('datetime', end.toIso8601String()) as List<dynamic>;

        for (final row in logData) {
          final log = VitalLog.fromJson(row as Map<String, dynamic>);
          if (log.timeslotId == null) continue;
          latest.putIfAbsent(log.vitalId, () => {});
          final existing = latest[log.vitalId]![log.timeslotId!];
          if (existing == null || log.datetime.isAfter(existing.datetime)) {
            latest[log.vitalId]![log.timeslotId!] = log;
          }
        }
      }

      setState(() {
        timeslots = loadedTimeslots;
        vitals = loadedVitals;
        latestLogs = latest;
      });
    } catch (e) {
      debugPrint('Error loading vitals data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load vitals.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------
  // VITAL CRUD
  // -------------------------
  Future<void> _addVital(Vital vital, List<Timeslot> selectedSlots) async {
    try {
      final patientId = await _resolvePatientId();

      final timeslotIds = selectedSlots.map((s) => s.id).toList();

      await supabase.from('Vital').insert({
        'vital_id': vital.id,
        'name': vital.name,
        'units': vital.units,
        'notes': vital.notes,
        'patient_id': patientId,
        'timeslot_ids': timeslotIds,
      });

      setState(() {
        vitals.add(vital.copyWith(timeslotIds: timeslotIds));
      });
    } catch (e) {
      debugPrint('Error adding vital: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add vital.')),
      );
    }
  }

  Future<void> _editVital(
    String id,
    String name,
    String units,
    String notes,
    List<Timeslot> selectedSlots,
  ) async {
    try {
      final timeslotIds = selectedSlots.map((t) => t.id).toList();

      await supabase
          .from('Vital')
          .update({
            'name': name,
            'units': units,
            'notes': notes,
            'timeslot_ids': timeslotIds,
          })
          .eq('vital_id', id);

      setState(() {
        vitals = vitals.map((v) {
          if (v.id == id) {
            return v.copyWith(
              name: name,
              units: units,
              notes: notes,
              timeslotIds: timeslotIds,
            );
          }
          return v;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error editing vital: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update vital.')),
      );
    }
  }

  Future<void> _deleteVital(String id) async {
    try {
      await supabase.from('VitalLog').delete().eq('vital_id', id);
      await supabase.from('Vital').delete().eq('vital_id', id);

      setState(() {
        vitals.removeWhere((v) => v.id == id);
        latestLogs.remove(id);
      });
    } catch (e) {
      debugPrint('Error deleting vital: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete vital.')),
      );
    }
  }

  // -------------------------
  // TIMESLOT CRUD
  // -------------------------
  Future<void> _addTimeslot(Timeslot slot, List<Vital> selectedVitals) async {
    try {
      final patientId = await _resolvePatientId();

      await supabase.from('VitalTimeslot').insert({
        'id': slot.id,
        'label': slot.label,
        'time':
            '${slot.time.hour.toString().padLeft(2, '0')}:${slot.time.minute.toString().padLeft(2, '0')}',
        'patient_id': patientId,
      });

      // Update each selected vital's timeslot_ids
      for (final v in selectedVitals) {
        final newIds = [...v.timeslotIds, slot.id];
        await supabase
            .from('Vital')
            .update({'timeslot_ids': newIds}).eq('vital_id', v.id);
      }

      setState(() {
        timeslots.add(slot);
        vitals = vitals.map((v) {
          if (selectedVitals.contains(v)) {
            return v.copyWith(timeslotIds: [...v.timeslotIds, slot.id]);
          }
          return v;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error adding timeslot: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add timeslot: $e')),
      );
    }
  }

  Future<void> _deleteTimeslot(String timeslotId) async {
    try {
      await supabase.from('VitalLog').delete().eq('timeslot_id', timeslotId);
      await supabase.from('VitalTimeslot').delete().eq('id', timeslotId);

      setState(() {
        timeslots.removeWhere((ts) => ts.id == timeslotId);

        // Remove from vitals
        vitals = vitals.map((v) {
          final newIds = List<String>.from(v.timeslotIds)..remove(timeslotId);
          return v.copyWith(timeslotIds: newIds);
        }).toList();
    //
        // Remove any latest logs for that timeslot
        latestLogs = latestLogs.map((vitalId, mapBySlot) {
          final newMap = Map<String, VitalLog>.from(mapBySlot)
            ..remove(timeslotId);
          return MapEntry(vitalId, newMap);
        });
      });
    } catch (error) {
      debugPrint('Failed to delete timeslot: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete timeslot. Please try again.')),
      );
    }
  }

  Future<void> _editTimeslot(
    String id,
    String label,
    TimeOfDay time,
    List<Vital> selectedVitals,
  ) async {
    try {
      // --- 1. Update VitalTimeslot ---
      await supabase.from('VitalTimeslot').update({
        'label': label,
        'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      }).eq('id', id);

      debugPrint('Timeslot updated');

      // --- 2. Prepare updates for Vital table ---
      final List<Future> updateFutures = [];
      final List<Vital> updatedVitals = [];

      for (final v in vitals) {
        final bool hasSlot = v.timeslotIds.contains(id);
        final bool isSelected = selectedVitals.contains(v);

        if (isSelected && !hasSlot) {
          // Add this timeslot ID
          final newIds = [...v.timeslotIds, id];

          updateFutures.add(
            supabase
                .from('Vital')
                .update({'timeslot_ids': newIds})
                .eq('vital_id', v.id),
          );

          updatedVitals.add(
            v.copyWith(timeslotIds: newIds),
          );
        } 
        else if (!isSelected && hasSlot) {
          // Remove this timeslot ID
          final newIds = v.timeslotIds.where((tid) => tid != id).toList();

          updateFutures.add(
            supabase
                .from('Vital')
                .update({'timeslot_ids': newIds})
                .eq('vital_id', v.id),
          );

          updatedVitals.add(
            v.copyWith(timeslotIds: newIds),
          );
        } 
        else {
          updatedVitals.add(v);
        }
      }

      // --- 3. WAIT for all Supabase updates ---
      await Future.wait(updateFutures);

      // --- 4. Now update widget state ---
      setState(() {
        timeslots = timeslots.map((slot) {
          if (slot.id == id) {
            return slot.copyWith(label: label, time: time);
          }
          return slot;
        }).toList();

        vitals = updatedVitals;
      });

      debugPrint('All updates applied successfully');

    } catch (e, stack) {
      debugPrint('Supabase update failed: $e');
      debugPrint(stack.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update timeslot.')),
      );
    }
  }


  // -------------------------
  // VITAL LOGS (per timeslot per day)
  // -------------------------
  Future<void> _upsertVitalLog(String vitalId, String timeslotId,
      {VitalLog? existing}) async {
    String valueStr = existing?.value.toString() ?? '';
    final controller = TextEditingController(text: valueStr);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Vital Value"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Value"),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final txt = controller.text.trim();
              if (txt.isEmpty) return;
              final val = double.tryParse(txt);
              if (val == null) return;
              Navigator.pop(context);

              try {
                final userId = supabase.auth.currentUser!.id;
                final now = DateTime.now();

                if (existing == null) {
                  final newId = const Uuid().v4();
                  await supabase.from('VitalLog').insert({
                    'vital_log_id': newId,
                    'vital_id': vitalId,
                    'timeslot_id': timeslotId,
                    'datetime': now.toIso8601String(),
                    'value': val,
                    'recorder_id': userId,
                  });

                  final newLog = VitalLog(
                    id: newId,
                    vitalId: vitalId,
                    timeslotId: timeslotId,
                    datetime: now,
                    value: val,
                    recorderId: userId,
                  );

                  setState(() {
                    latestLogs.putIfAbsent(vitalId, () => {});
                    latestLogs[vitalId]![timeslotId] = newLog;
                  });
                } else {
                  await supabase
                      .from('VitalLog')
                      .update({
                        'value': val,
                        'datetime': now.toIso8601String(),
                        'timeslot_id': timeslotId,
                      })
                      .eq('vital_log_id', existing.id);

                  final updatedLog = existing.copyWith(
                    value: val,
                    datetime: now,
                    timeslotId: timeslotId
                  );

                  setState(() {
                    latestLogs.putIfAbsent(vitalId, () => {});
                    latestLogs[vitalId]![timeslotId] = updatedLog;
                  });
                }
              } catch (e) {
                debugPrint('Error upserting vital log: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to save vital log.')),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVitalLog(String vitalId, String timeslotId) async {
    final log = latestLogs[vitalId]?[timeslotId];
    if (log == null) return;

    try {
      await supabase
          .from('VitalLog')
          .delete()
          .eq('vital_log_id', log.id);

      setState(() {
        final mapBySlot = latestLogs[vitalId];
        if (mapBySlot != null) {
          mapBySlot.remove(timeslotId);
        }
      });
    } catch (e) {
      debugPrint('Error deleting vital log: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete vital log.')),
      );
    }
  }

  // -------------------------
  // BUILD
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Vitals"),
          centerTitle: true,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C8DA7), Color(0xFF5C7C9D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Timeline"),
              Tab(text: "My Vitals"),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
          actions: const [
            ProfileMenuButton(),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  VitalsTimelineScreen(
                    vitals: vitals,
                    timeslots: timeslots,
                    latestLogs: latestLogs,
                    getVitalColor: _getVitalColor,
                    addTimeslot: _addTimeslot,
                    deleteTimeslot: _deleteTimeslot,
                    editTimeslot: _editTimeslot,
                    upsertVitalLog: _upsertVitalLog,
                    deleteVitalLog: _deleteVitalLog,
                  ),
                  MyVitalsScreen(
                    vitals: vitals,
                    timeslots: timeslots,
                    getVitalColor: _getVitalColor,
                    addVital: _addVital,
                    editVital: _editVital,
                    deleteVital: _deleteVital,
                  ),
                ],
              ),
      ),
    );
  }
}

void _showVitalLogsDialog(BuildContext context, Vital vital) async {
  final supabase = Supabase.instance.client;

  // Fetch logs for this vital
  final response = await supabase
      .from('VitalLog')
      .select()
      .eq('vital_id', vital.id)
      .order('datetime', ascending: false);

  final logs = response as List<dynamic>;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("${vital.name} (${vital.units}) Logs"),
        content: logs.isEmpty
            ? const Text("No logs recorded yet.")
            : SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: logs.map((log) {
                    final dt = DateTime.parse(log['datetime']).toLocal();
                    final timestamp = "${dt.month}/${dt.day}/${dt.year} at ${TimeOfDay.fromDateTime(dt).format(context)}";
                    return ListTile(
                      title: Text("Value: ${log['value']} ${vital.units}"),
                      subtitle: Text("Recorded on $timestamp\nNotes: ${log['notes'] ?? "none"}"),
                    );
                  }).toList(),
                ),
              ),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      );
    },
  );
}


// -----------------------------
// TIMELINE VIEW (like Medication)
// -----------------------------
class VitalsTimelineScreen extends StatelessWidget {
  final List<Vital> vitals;
  final List<Timeslot> timeslots;
  final Map<String, Map<String, VitalLog>> latestLogs;
  final Color Function(String vitalId) getVitalColor;
  final void Function(Timeslot slot, List<Vital> selectedVitals) addTimeslot;
  final void Function(String timeslotId) deleteTimeslot;
  final void Function(
    String id,
    String label,
    TimeOfDay time,
    List<Vital> selectedVitals,
  ) editTimeslot;
  final Future<void> Function(
    String vitalId,
    String timeslotId, {
    VitalLog? existing,
  }) upsertVitalLog;
  final Future<void> Function(
    String vitalId,
    String timeslotId,
  ) deleteVitalLog;

  const VitalsTimelineScreen({
    super.key,
    required this.vitals,
    required this.timeslots,
    required this.latestLogs,
    required this.getVitalColor,
    required this.addTimeslot,
    required this.deleteTimeslot,
    required this.editTimeslot,
    required this.upsertVitalLog,
    required this.deleteVitalLog,
  });

  @override
  Widget build(BuildContext context) {
    final sortedSlots = timeslots.toList()
      ..sort((a, b) {
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...sortedSlots.map((slot) {
          final slotVitals = vitals
              .where((v) => v.timeslotIds.contains(slot.id))
              .toList();

          return VitalTimeslotCard(
            slot: slot,
            vitals: slotVitals,
            allVitals: vitals,
            latestLogs: latestLogs,
            getVitalColor: getVitalColor,
            deleteTimeslot: deleteTimeslot,
            editTimeslot: editTimeslot,
            upsertVitalLog: upsertVitalLog,
            deleteVitalLog: deleteVitalLog,
          );
        }).toList(),
        const SizedBox(height: 12),
        ElevatedButton(
          child: const Text("+ Add Timeslot"),
          onPressed: () {
            String newLabel = "";
            TimeOfDay selectedTime = TimeOfDay.now();
            List<Vital> selectedVitals = [];

            showDialog(
              context: context,
              builder: (context) {
                return StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return AlertDialog(
                      title: const Text("Add Timeslot"),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                labelText: "Timeslot Name",
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) => newLabel = val,
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                  initialEntryMode:
                                      TimePickerEntryMode.input,
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
                            const Text(
                              "Assign to Vitals:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: vitals.map((v) {
                                final isSelected = selectedVitals.contains(v);
                                return FilterChip(
                                  label: Text(
                                    v.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: Colors.blue,
                                  backgroundColor: Colors.grey.shade300,
                                  side: BorderSide(
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.grey,
                                  ),
                                  showCheckmark: false,
                                  onSelected: (selected) {
                                    setStateDialog(() {
                                      if (selected) {
                                        selectedVitals.add(v);
                                      } else {
                                        selectedVitals.remove(v);
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
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (newLabel.isNotEmpty) {
                              final newSlot = Timeslot(
                                label: newLabel,
                                id: const Uuid().v4(),
                                time: selectedTime,
                              );
                              addTimeslot(newSlot, selectedVitals);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Added '${newSlot.label}' at '${newSlot.time.format(context)}' and assigned ${selectedVitals.length} vitals.",
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text("Save"),
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

class VitalTimeslotCard extends StatelessWidget {
  final Timeslot slot;
  final List<Vital> vitals;
  final List<Vital> allVitals;
  final Map<String, Map<String, VitalLog>> latestLogs;
  final Color Function(String vitalId) getVitalColor;
  final void Function(String timeslotId) deleteTimeslot;
  final void Function(
    String id,
    String label,
    TimeOfDay time,
    List<Vital> selectedVitals,
  ) editTimeslot;
  final Future<void> Function(
    String vitalId,
    String timeslotId, {
    VitalLog? existing,
  }) upsertVitalLog;
  final Future<void> Function(
    String vitalId,
    String timeslotId,
  ) deleteVitalLog;

  const VitalTimeslotCard({
    super.key,
    required this.slot,
    required this.vitals,
    required this.allVitals,
    required this.latestLogs,
    required this.getVitalColor,
    required this.deleteTimeslot,
    required this.editTimeslot,
    required this.upsertVitalLog,
    required this.deleteVitalLog,
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
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    String editedLabel = slot.label;
                    TimeOfDay editedTime = slot.time;

                    List<Vital> selectedVitals = [];
                    for (Vital v in allVitals) {
                      if (v.timeslotIds.contains(slot.id)) {
                        selectedVitals.add(v);
                      }
                    }

                    showDialog(
                      context: context,
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (context, setStateDialog) {
                            final labelController =
                                TextEditingController(text: editedLabel);
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
                                      controller: labelController,
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
                                    const Text("Assigned Vitals:"),
                                    Wrap(
                                      spacing: 6,
                                      children: allVitals.map((v) {
                                        final isSelected =
                                            selectedVitals.contains(v);
                                        return FilterChip(
                                          label: Text(
                                            v.name,
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
                                                selectedVitals.add(v);
                                              } else {
                                                selectedVitals.remove(v);
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
                                        selectedVitals,
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
        children: vitals.map((v) {
          final color = getVitalColor(v.id);
          final log = latestLogs[v.id]?[slot.id];
          final valueText =
              log != null ? "${log.value}" : "No value logged yet";
          final timeText = log != null
              ? TimeOfDay(
                      hour: log.datetime.toLocal().hour,
                      minute: log.datetime.toLocal().minute)
                  .format(context)
              : "";
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1.5),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                v.units.isNotEmpty ? "${v.name} (${v.units})" : v.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                log != null ? "Value: $valueText at $timeText" : valueText,
              ),
              trailing: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => upsertVitalLog(v.id, slot.id, existing: log),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text("Record Vital"),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: log == null ? null : () => deleteVitalLog(v.id, slot.id),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text("Delete Recorded Vital"),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// -----------------------------
// MY VITALS VIEW (like My Medications)
// -----------------------------
class MyVitalsScreen extends StatelessWidget {
  final List<Vital> vitals;
  final List<Timeslot> timeslots;
  final Color Function(String vitalId) getVitalColor;
  final Future<void> Function(Vital vital, List<Timeslot> selectedSlots)
      addVital;
  final Future<void> Function(
    String id,
    String name,
    String units,
    String notes,
    List<Timeslot> selectedSlots,
  ) editVital;
  final Future<void> Function(String id) deleteVital;

  const MyVitalsScreen({
    super.key,
    required this.vitals,
    required this.timeslots,
    required this.getVitalColor,
    required this.addVital,
    required this.editVital,
    required this.deleteVital,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...vitals.map((v) {
          final color = getVitalColor(v.id);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1.5),
            ),
            child: ListTile(
              title: Text(
                v.units.isNotEmpty ? "${v.name} (${v.units})" : v.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("Notes: ${v.notes}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    child: const Text("Logs"),
                    onPressed: () {
                      _showVitalLogsDialog(context, v);
                    },
                  ),
                  TextButton(
                    child: const Text("Edit"),
                    onPressed: () {
                      List<Timeslot> tempSelectedSlots = timeslots
                          .where((ts) => v.timeslotIds.contains(ts.id))
                          .toList();

                      showDialog(
                        context: context,
                        builder: (context) {
                          final nameController =
                              TextEditingController(text: v.name);
                          final unitsController =
                              TextEditingController(text: v.units);
                          final notesController =
                              TextEditingController(text: v.notes);

                          return StatefulBuilder(
                            builder: (context, setStateDialog) {
                              return AlertDialog(
                                title: const Text("Edit Vital"),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: nameController,
                                        decoration: const InputDecoration(
                                            labelText: "Name"),
                                      ),
                                      TextField(
                                        controller: unitsController,
                                        decoration: const InputDecoration(
                                            labelText: "Units"),
                                      ),
                                      TextField(
                                        controller: notesController,
                                        decoration: const InputDecoration(
                                            labelText: "Notes"),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text("Assign to Timeslots:"),
                                      Wrap(
                                        spacing: 6,
                                        children: timeslots.map((slot) {
                                          final isSelected = tempSelectedSlots
                                              .contains(slot);
                                          return FilterChip(
                                            label: Text(
                                              "${slot.label} ${slot.time.format(context)}",
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                            selected: isSelected,
                                            selectedColor: Colors.blue,
                                            backgroundColor:
                                                Colors.grey.shade300,
                                            side: BorderSide(
                                              color: isSelected
                                                  ? Colors.blue
                                                  : Colors.grey,
                                            ),
                                            showCheckmark: false,
                                            onSelected: (selected) {
                                              setStateDialog(() {
                                                if (selected) {
                                                  tempSelectedSlots.add(slot);
                                                } else {
                                                  tempSelectedSlots
                                                      .remove(slot);
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
                                      child: const Text("Cancel")),
                                  ElevatedButton(
                                    onPressed: () {
                                      final newName =
                                          nameController.text.trim();
                                      final newUnits =
                                          unitsController.text.trim();
                                      final newNotes =
                                          notesController.text.trim();
                                      if (newName.isNotEmpty) {
                                        editVital(
                                          v.id,
                                          newName,
                                          newUnits,
                                          newNotes,
                                          tempSelectedSlots,
                                        );
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: const Text("Save"),
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
                          title: const Text("Delete Vital"),
                          content: Text(
                              "Are you sure you want to delete '${v.name}' and its logs?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                deleteVital(v.id);
                                Navigator.pop(ctx);
                              },
                              child: const Text("Delete"),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
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
          child: const Text("+ Add Vital"),
          onPressed: () {
            String name = "";
            String units = "";
            String notes = "";
            List<Timeslot> tempSelectedSlots = [];

            showDialog(
              context: context,
              builder: (context) {
                return StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return AlertDialog(
                      title: const Text("Add Vital"),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              decoration:
                                  const InputDecoration(labelText: "Name"),
                              onChanged: (val) => name = val,
                            ),
                            TextField(
                              decoration:
                                  const InputDecoration(labelText: "Units"),
                              onChanged: (val) => units = val,
                            ),
                            TextField(
                              decoration:
                                  const InputDecoration(labelText: "Notes"),
                              onChanged: (val) => notes = val,
                            ),
                            const SizedBox(height: 12),
                            const Text("Assign to Timeslots:"),
                            Wrap(
                              spacing: 6,
                              children: timeslots.map((slot) {
                                final isSelected =
                                    tempSelectedSlots.contains(slot);
                                return FilterChip(
                                  label: Text(
                                    slot.label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: Colors.blue,
                                  backgroundColor: Colors.grey.shade300,
                                  side: BorderSide(
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.grey,
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
                            child: const Text("Cancel")),
                        ElevatedButton(
                          onPressed: () {
                            if (name.isNotEmpty) {
                              final newVital = Vital(
                                id: const Uuid().v4(),
                                name: name,
                                units: units,
                                notes: notes,
                                timeslotIds:
                                    tempSelectedSlots.map((s) => s.id).toList(),
                              );
                              addVital(newVital, tempSelectedSlots);
                              Navigator.pop(context);
                            }
                          },
                          child: const Text("Save"),
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



