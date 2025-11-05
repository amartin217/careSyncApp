import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/caregiver.dart';
import '../widgets/profile_menu.dart';
import 'package:intl/intl.dart'; // For formatting timestamps

class MessagingPage extends StatefulWidget {
  const MessagingPage({super.key});

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final List<Message> messages = [
  Message(
    id: "1",
    text: "Hi there!",
    from: Caregiver(id: "1000", name: "Another Caregiver Name", color: Colors.green.shade100),
    timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
  ),
  Message(
    id: "2",
    text: "How are you today?",
    from: Caregiver(id: "1001", name: "You", color: Colors.blue.shade100),
    timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
  ),
  ];
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _controller.text.trim(),
      from: Caregiver(id: "1000", name: "You", color: Colors.blue.shade100),
      timestamp: DateTime.now(),
    );

    setState(() {
      messages.add(newMessage);
      _controller.clear();
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('hh:mm a').format(timestamp); // e.g., 08:41 PM
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messaging"),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: const [ProfileMenuButton()],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Align(
                  alignment: msg.from.name == "You"
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.from.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg.text),
                        const SizedBox(height: 4),
                        Text(
                          '${msg.from.name} • ${_formatTimestamp(msg.timestamp)}',
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