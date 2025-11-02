import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'link_patient_page.dart';
import '../widgets/profile_menu.dart';

class DashboardPage extends StatelessWidget {
  DashboardPage({super.key});

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

  Future<Map<String, dynamic>?> _fetchUserProfile() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    // Fetch current user's profile
    final profile = await supabase
        .from('Profile')
        .select('user_id, is_patient, name')
        .eq('user_id', userId)
        .maybeSingle();

    if (profile == null) return null;

    if (profile['is_patient'] == true) {
      // 🧍 Patient user
      final patientCode = await supabase
          .from('PatientCode')
          .select('code')
          .eq('patient_id', userId)
          .maybeSingle();

      return {
        'is_patient': true,
        'name': profile['name'] ?? 'User',
        'code': patientCode?['code'],
      };
    } else {
      // 👩‍⚕️ Caregiver user
      final relation = await supabase
          .from('CareRelation')
          .select('patient_id')
          .eq('user_id', userId)
          .maybeSingle();

      String? patientName;

      if (relation != null) {
        final patientProfile = await supabase
            .from('Profile')
            .select('name')
            .eq('user_id', relation['patient_id'])
            .maybeSingle();

        patientName = patientProfile?['name'];
      }

      return {
        'is_patient': false,
        'name': profile['name'] ?? 'User',
        'patient_name': patientName ?? 'your patient',
        'has_patient_linked': relation != null,
      };
    }
  }



  Future<Map<String, List<Map<String, dynamic>>>> _fetchMedications() async {
    final supabase = Supabase.instance.client;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final userId = supabase.auth.currentUser!.id;

    // Determine patient
    final relation = await supabase
        .from('CareRelation')
        .select('patient_id')
        .eq('user_id', userId)
        .maybeSingle();
    final patientId =
        relation != null ? relation['patient_id'] as String : userId;

    // Fetch data
    final timeslots = await supabase
        .from('Timeslot')
        .select()
        .eq('patient_id', patientId);

    final meds = await supabase
        .from('Medication')
        .select()
        .eq('patient_id', patientId);

    final logs = await supabase
        .from('MedicationLog')
        .select()
        .eq('patient_id', patientId)
        .eq('date', today);

    final now = TimeOfDay.now();
    final missed = <Map<String, dynamic>>[];
    final upcoming = <Map<String, dynamic>>[];

    for (final slot in timeslots) {
      final timeParts = (slot['time'] as String).split(':');
      final slotTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
      final slotId = slot['id'] as String;

      final slotMeds = meds.where((m) {
        final ids = (m['timeslot_ids'] as List?)?.cast<String>() ?? [];
        return ids.contains(slotId);
      });

      for (final m in slotMeds) {
        final matchingLogs = logs.where((l) =>
          l['medication_id'] == m['id'] && l['timeslot_id'] == slotId).toList();
        final log = matchingLogs.isNotEmpty ? matchingLogs.first : null;
        final isTaken = log != null ? (log['is_taken'] as bool? ?? false) : false;

        final item = {
          'id': m['id'],
          'name': m['name'],
          'dosage': m['dosage'],
          'label': slot['label'],
          'time': slotTime,
          'isTaken': isTaken,
        };

        final slotMinutes = slotTime.hour * 60 + slotTime.minute;
        final nowMinutes = now.hour * 60 + now.minute;
        if (!isTaken && slotMinutes < nowMinutes) {
          missed.add(item);
        } else if (slotMinutes >= nowMinutes) {
          upcoming.add(item);
        }
      }
    }

    missed.sort((a, b) =>
        (a['time'].hour * 60 + a['time'].minute)
            .compareTo(b['time'].hour * 60 + b['time'].minute));
    upcoming.sort((a, b) =>
        (a['time'].hour * 60 + a['time'].minute)
            .compareTo(b['time'].hour * 60 + b['time'].minute));

    return {'missed': missed, 'upcoming': upcoming};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchUserProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
  
        final data = snapshot.data!;
        final isPatient = data['is_patient'] == true;
        final userName = data['name'] ?? 'User';
        final patientName = data['patient_name'];
        final hasLinkedPatient = data['has_patient_linked'] == true;
  
        String welcomeLine;
        if (isPatient) {
          welcomeLine = "Hi $userName, here is your health overview for today:";
        } else if (hasLinkedPatient) {
          welcomeLine =
              "Hi $userName, here is ${patientName ?? 'your patient'}'s health overview for today:";
        } else {
          welcomeLine =
              "Hi $userName, please link a patient to view their health overview.";
        }
  
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text("Dashboard"),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            actions: const [
              ProfileMenuButton(),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 👋 Personalized welcome section
                Text(
                  "Welcome, $userName!👋",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  welcomeLine,
                  style: const TextStyle(fontSize: 18, color: Colors.black),
                ),
                const SizedBox(height: 24),
  
                if (isPatient) ...[
                  Text(
                    "Your Share Code:",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    data['code'] ?? 'No code found',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
  
                if (!isPatient && !hasLinkedPatient)
                  const Center(
                    child: Text(
                      "No patient linked yet. Use the link page to connect with a patient.",
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else
                  FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
                    future: _fetchMedications(),
                    builder: (context, medsSnapshot) {
                      if (!medsSnapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
  
                      final missed = medsSnapshot.data!['missed']!;
                      final upcoming = medsSnapshot.data!['upcoming']!;
  
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (missed.isNotEmpty) ...[
                            const Row(
                              children: [
                                Text(
                                  "Missed Medications",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 24.0,
                                  semanticLabel: 'Missed Medication Icon',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: missed
                                  .map((m) => _buildMedTile(context, m))
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                          const Text(
                            "Today's Upcoming Medications",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (upcoming.isEmpty)
                            const Text("No upcoming medications."),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: upcoming
                                .map((m) => _buildMedTile(context, m))
                                .toList(),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildMedTile(BuildContext context, Map<String, dynamic> med) {
    final time = med['time'] as TimeOfDay;
    final timeStr = time.format(context);
    final medColor = _getMedColor(med['id']);
  
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: medColor.withOpacity(0.2), // background tint
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: medColor, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${med['name'] ?? 'Unnamed'} - ${med['dosage'] ?? ''}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            "${med['label'] ?? ''} ($timeStr)",
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
  

}

