import 'package:flutter/material.dart';

class VitalsPage extends StatelessWidget {
  const VitalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Vitals Tracking")),
      body: Center(child: Text("Log vitals like blood pressure, heart rate.")),
    );
  }
}