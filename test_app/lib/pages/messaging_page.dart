import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/caregiver.dart';
import '../widgets/profile_menu.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class MessagingPage extends StatefulWidget {
  const MessagingPage({super.key});

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  String? patientId;
  final List<Message> messages = [];

  final TextEditingController _controller = TextEditingController();
  List<Caregiver> caregivers = [];
  bool isLoadingCaregivers = true;

  late final SupabaseClient supabase;
  late final String currentUserId;

  @override
  void initState() {
    super.initState();

    supabase = Supabase.instance.client;
    currentUserId = supabase.auth.currentUser!.id;

    _loadMessages();
    _loadCaregivers();
  }

  Future<void> _loadMessages() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser!;

    // 1. Get patient_id for this user
    final relation = await supabase
        .from('CareRelation')
        .select('patient_id')
        .eq('user_id', currentUser.id)
        .maybeSingle();

    if (relation == null) {
      return;
    } 

    final curPatientId = relation['patient_id'];

    // 2. Load messages for this patient
    final response = await supabase
        .from('Message')
        .select()
        .eq('patient_id', curPatientId)
        .order('timestamp', ascending: true);

    // 3. Convert to Message objects
    final loaded = response
        .map<Message>((row) => Message.fromMap(row))
        .toList();

    // 4. Update UI
    setState(() {
      patientId = curPatientId;   // from your logic
      messages
        ..clear()
        ..addAll(loaded);
    });

  }


  // -----------------------------
  // LOAD CAREGIVERS FOR PATIENT OR CAREGIVER
  // -----------------------------
  Future<void> _loadCaregivers() async {
    final currentUser = supabase.auth.currentUser!;

    // First get the profile
    final profile = await supabase
        .from('Profile')
        .select('is_patient')
        .eq('user_id', currentUser.id)
        .maybeSingle();

    final isPatient = profile?['is_patient'] ?? false;

    // Then fetch the caregivers
    final fetchedCaregivers = await fetchCaregivers(isPatient);

    setState(() {
      caregivers = fetchedCaregivers;
      isLoadingCaregivers = false;
    });
  }

  // -----------------------------
  // FETCH CAREGIVER RELATIONSHIPS
  // -----------------------------
  Color parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.blue.shade100; // fallback

    // Remove # if present
    final hex = hexColor.replaceAll('#', '');

    // Add alpha FF if missing
    final buffer = StringBuffer();
    if (hex.length == 6) buffer.write('FF'); // full opacity
    buffer.write(hex);

    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<List<Caregiver>> fetchCaregivers(bool isPatient) async {
    final currentUser = supabase.auth.currentUser!;

    List<Map<String, dynamic>> response = [];

    if (isPatient) {
      // fetch caregivers linked to this patient
      response = await supabase
          .from('CareRelation')
          .select('user_id, profile:user_id (name)')
          .eq('patient_id', currentUser.id);

    } else {
      // caregiver -> find your patient_id first
      final relation = await supabase
          .from('CareRelation')
          .select('patient_id')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (relation == null) return [];

      final patientId = relation['patient_id'];

      // fetch caregiver list for the same patient
      response = await supabase
          .from('CareRelation')
          .select('user_id, profile:user_id (name, color)')
          .eq('patient_id', patientId);
    }

    // Map caregivers
    return response.map((row) {
      return Caregiver(
        id: row['user_id'],
        name: row['profile']?['name'] ?? 'Unknown',
        color: parseColor(row['profile']?['color']),
      );
    }).toList();
  }

  // -----------------------------
  // SEND MESSAGE
  // -----------------------------
  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    if (patientId == null) {
      print("Cannot send message — patientId is null");
      return;
    }

    final text = _controller.text.trim();

    final newMsg = Message(
      id: const Uuid().v4(),
      text: text,
      fromId: currentUserId,
      timestamp: DateTime.now(),
    );

    // Insert into Supabase
    final payload = {
      'id': newMsg.id,
      'text': newMsg.text,
      'from': newMsg.fromId,
      'patient_id': patientId,
      'timestamp': newMsg.timestamp.toIso8601String(),
    };

    final response = await supabase.from('Message').insert(payload);

    // Update UI locally so message appears immediately
    setState(() {
      messages.add(newMsg);
      _controller.clear();
    });
  }


  // -----------------------------
  // TIMESTAMP FORMATTER
  // -----------------------------
  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('MMM d, yyyy • hh:mm a').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while caregivers are loading
    if (isLoadingCaregivers) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text("Messages"),
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
                colors: [Color(0xFF6C8DA7), Color(0xFF5C7C9D)], // soft gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: const [
            ProfileMenuButton(),
          ],
        ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];

                // find caregiver by ID
                final caregiver = caregivers.firstWhere(
                  (c) => c.id == msg.fromId,
                  orElse: () => Caregiver(
                    id: msg.fromId,
                    name: "Unknown",
                    color: Colors.grey.shade300,
                  ),
                );
                return Align(
                  alignment: caregiver.id == currentUserId
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: caregiver.color.withOpacity(0.1),
                      //borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: caregiver.color, width: 1.5),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: caregiver.id == currentUserId
                            ? const Radius.circular(16)
                            : const Radius.circular(4),             // "tail" side
                        bottomRight: caregiver.id == currentUserId
                            ? const Radius.circular(4)
                            : const Radius.circular(16),            // "tail" side
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg.text),
                        const SizedBox(height: 4),
                        Text(
                          '${caregiver.name} • ${_formatTimestamp(msg.timestamp)}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
