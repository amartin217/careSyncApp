// lib/main.dart
import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/medication_page.dart';
import 'pages/vitals_page.dart';
import 'pages/calendar_page.dart';
import 'pages/messaging_page.dart';

void main() {
  runApp(CaregiverSupportApp());
}

class CaregiverSupportApp extends StatelessWidget {
  const CaregiverSupportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caregiver Support',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    DashboardPage(),
    MedicationPage(),
    VitalsPage(),
    CalendarPage(),
    MessagingPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.local_hospital), label: 'Medication'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Vitals'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messaging'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
