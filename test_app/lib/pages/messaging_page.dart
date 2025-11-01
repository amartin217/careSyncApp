import 'package:flutter/material.dart';
import '../widgets/profile_menu.dart';

class MessagingPage extends StatelessWidget {
  const MessagingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Messaging"),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: const [
          ProfileMenuButton(),
        ],
      ),
      body: Center(child: Text("Communicate with caregivers and family.")),
    );
  }
}