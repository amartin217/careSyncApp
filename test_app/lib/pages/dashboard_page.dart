import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/profile_menu.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatelessWidget {
  DashboardPage({super.key});

  final Map<String, Color> medColors = {};

  final List<MaterialColor> colors = [
    Colors.lightBlue,
    Colors.orange,
    Colors.green,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.deepOrange,
    Colors.cyan,
    Colors.lime,
    Colors.brown,
    Colors.blueGrey,
  ];

  Color _getMedColor(String medId) {
    if (!medColors.containsKey(medId)) {
      final index = medColors.length % colors.length;
      medColors[medId] = colors[index].shade300;
    }
    return medColors[medId]!;
  }

  Color _getMedDarkColor(String medId) {
    final index = medColors.keys.toList().indexOf(medId) % colors.length;
    return colors[index].shade700;
  }

  Future<Map<String, dynamic>?> _fetchUserProfile() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final profile = await supabase
        .from('Profile')
        .select('user_id, is_patient, name')
        .eq('user_id', userId)
        .maybeSingle();

    if (profile == null) return null;

    if (profile['is_patient'] == true) {
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

    final relation = await supabase
        .from('CareRelation')
        .select('patient_id')
        .eq('user_id', userId)
        .maybeSingle();

    final patientId =
        relation != null ? relation['patient_id'] as String : userId;

    final timeslots =
        await supabase.from('Timeslot').select().eq('patient_id', patientId);

    final meds =
        await supabase.from('Medication').select().eq('patient_id', patientId);

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
        final matchingLogs = logs
            .where((l) =>
                l['medication_id'] == m['id'] && l['timeslot_id'] == slotId)
            .toList();
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
        } else if (!isTaken && slotMinutes >= nowMinutes) {
          upcoming.add(item);
        }
      }
    }

    missed.sort((a, b) => (a['time'].hour * 60 + a['time'].minute)
        .compareTo(b['time'].hour * 60 + b['time'].minute));
    upcoming.sort((a, b) => (a['time'].hour * 60 + a['time'].minute)
        .compareTo(b['time'].hour * 60 + b['time'].minute));

    return {'missed': missed, 'upcoming': upcoming};
  }

  Future<List<Map<String, dynamic>>> _fetchUpcomingEvents(
      {required bool isPatient}) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;
    final now = DateTime.now().toIso8601String();

    List<dynamic> events;

    if (isPatient) {
      events = await supabase
          .from('Event')
          .select('event_id, name, start_datetime, end_datetime, description')
          .eq('patient_id', userId)
          .gte('start_datetime', now)
          .order('start_datetime', ascending: true);
    } else {
      events = await supabase
          .from('Event')
          .select('event_id, name, start_datetime, end_datetime, description')
          .eq('assigned_user', userId)
          .gte('start_datetime', now)
          .order('start_datetime', ascending: true);
    }

    return (events as List).map((e) => e as Map<String, dynamic>).toList();
  }

  // -------------------
  // SECTION CARD HELPER
  // -------------------

  Widget _sectionCard({
    required String title,
    required Widget child,
    Color? color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
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
          welcomeLine = "Here is your health overview for today:";
        } else if (hasLinkedPatient) {
          welcomeLine =
              "Here is ${patientName ?? 'your patient'}'s health overview for today:";
        } else {
          welcomeLine =
              "Please link a patient to view their health overview.";
        }

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text("Dashboard"),
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
            actions: const [ProfileMenuButton()],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Welcome, $userName!👋",
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).primaryColorDark)),
                const SizedBox(height: 4),
                Text(welcomeLine,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 24),

                if (isPatient)
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Your Patient Share Code:",
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            SelectableText(
                              data['code'] ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),

                if (!isPatient && !hasLinkedPatient)
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    child: Center(
                      child: Text(
                        "No patient linked yet. Use the link page to connect with a patient.",
                        style: TextStyle(
                            color: Colors.black54,
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  FutureBuilder<
                      Map<String, List<Map<String, dynamic>>>>(
                    future: _fetchMedications(),
                    builder: (context, medsSnapshot) {
                      if (!medsSnapshot.hasData) {
                        return const Center(
                            child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: CircularProgressIndicator(),
                        ));
                      }

                      final missed = medsSnapshot.data!['missed']!;
                      final upcoming = medsSnapshot.data!['upcoming']!;

                      return Column(
                        children: [
                          // MISSED DOSES CARD -----------------------
                          if (missed.isNotEmpty)
                            _sectionCard(
                              title: "⚠️ Missed Doses",
                              color: Colors.red.shade50,
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: missed
                                    .map((m) => _buildMedTile(context, m))
                                    .toList(),
                              ),
                            ),

                          const SizedBox(height: 24),

                          // UPCOMING MEDS CARD ---------------------
                          _sectionCard(
                            title: "💊 Today's Upcoming Medications",
                            child: upcoming.isEmpty
                                ? Text(
                                    "No upcoming medications today. You are all caught up!",
                                    style:
                                        TextStyle(color: Colors.black54),
                                  )
                                : Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: upcoming
                                        .map((m) => _buildMedTile(context, m))
                                        .toList(),
                                  ),
                          ),

                          const SizedBox(height: 24),

                          // UPCOMING EVENTS CARD -------------------
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _fetchUpcomingEvents(isPatient: isPatient),
                            builder: (context, eventSnapshot) {
                              if (!eventSnapshot.hasData) {
                                return const Center(
                                    child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20.0),
                                  child: CircularProgressIndicator(),
                                ));
                              }

                              final events = eventSnapshot.data!;

                              return _sectionCard(
                                title: "🗓️ Upcoming Appointments",
                                child: events.isEmpty
                                    ? Text(
                                        "No upcoming appointments.",
                                        style:
                                            TextStyle(color: Colors.black54),
                                      )
                                    : Column(
                                        children: events
                                            .map((e) =>
                                                _buildEventTile(context, e))
                                            .toList(),
                                      ),
                              );
                            },
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

  // ------------------------
  // MED TILE + EVENT TILE UI
  // ------------------------

  Widget _buildMedTile(BuildContext context, Map<String, dynamic> med) {
    final time = med['time'] as TimeOfDay;
    final timeStr = time.format(context);
    final medColor = _getMedColor(med['id']);
    final medDarkColor = _getMedDarkColor(med['id']);

    final isMissed = med['isTaken'] == false &&
        (time.hour * 60 + time.minute) <
            (TimeOfDay.now().hour * 60 + TimeOfDay.now().minute);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isMissed ? Colors.red.shade400 : medColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isMissed ? Colors.red.shade50 : medColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              med['name'] ?? 'Unnamed Medication',
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 16,
                    color: isMissed
                        ? Colors.red.shade700
                        : medDarkColor),
                const SizedBox(width: 4),
                Text(
                  "${med['label'] ?? 'Dose'} ($timeStr)",
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              med['dosage'] ?? 'Unknown dosage',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(BuildContext context, Map<String, dynamic> event) {
    final start = DateTime.parse(event['start_datetime']);
    final end = DateTime.parse(event['end_datetime']);
    final dateStr = DateFormat('EEE, MMM d').format(start);
    final timeStr =
        "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.calendar_month,
              size: 28, color: Colors.teal),
        ),
        title: Text(
          event['name'] ?? 'Untitled Event',
          style: Theme.of(context)
              .textTheme
              .titleMedium!
              .copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              timeStr,
              style:
                  const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (event['description'] != null &&
                (event['description'] as String).trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  event['description'],
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

