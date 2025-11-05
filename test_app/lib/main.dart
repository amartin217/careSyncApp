// lib/main.dart
import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/medication_page.dart';
import 'pages/vitals_page.dart';
import 'pages/calendar_page.dart';
import 'pages/messaging_page.dart';
import 'pages/link_patient_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/vitals_config_page.dart';
import 'models/vital.dart';
import 'models/vital_timeslot.dart';
import 'models/vital_reading.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kslxhihlmviquoetrpjh.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzbHhoaWhsbXZpcXVvZXRycGpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5NDAxMTcsImV4cCI6MjA3NTUxNjExN30.g1yYb5JHMIvN6DHdw0WQ_TAAyWL-oEHTEPazZukoGjc',
  );
  runApp(const CaregiverSupportApp());
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
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _determineLandingPage() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return const LoginPage();

    // Fetch profile
    final profile = await supabase
        .from('Profile')
        .select('is_patient')
        .eq('user_id', user.id)
        .maybeSingle();
    if (profile == null) return const LoginPage();

    if (profile['is_patient'] == true) {
      return const MainPage(); // patients always go to dashboard
    } else {
      // caregiver: check if they have a linked patient
      final relation = await supabase
          .from('CareRelation')
          .select('patient_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (relation == null) {
        return const LinkPatientPage(); // only see link page
      } else {
        return const MainPage(); // linked → normal tabs
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _determineLandingPage(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!;
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                setState(() => errorMessage = null);
                try {
                  final res = await Supabase.instance.client.auth.signInWithPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                  );
                  if (res.session != null && context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                    );
                  }
                } on AuthException catch (e) {
                  setState(() => errorMessage = e.message);
                } catch (e) {
                  setState(() => errorMessage = 'Unexpected error: $e');
                }    
              },
              child: const Text('Login'),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpPage()),
                );
              },
              child: const Text('Create account'),
            )
          ],
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  bool? isPatient; // Nullable until user chooses Yes or No
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            const Text(
              'Are you a patient?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                RadioListTile<bool>(
                  title: const Text('Yes'),
                  value: true,
                  groupValue: isPatient,
                  onChanged: (val) => setState(() => isPatient = val),
                ),
                RadioListTile<bool>(
                  title: const Text('No'),
                  value: false,
                  groupValue: isPatient,
                  onChanged: (val) => setState(() => isPatient = val),
                ),
              ],
            ),            
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (isPatient == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select Yes or No')),
                  );
                  return;
                }

                try {
                  final supabase = Supabase.instance.client;

                  // 1️⃣ Create user in Auth
                  final res = await supabase.auth.signUp(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );

                  final user = res.user ?? supabase.auth.currentUser;
                  if (user == null) throw Exception('User creation failed');

                  // 2️⃣ Insert profile
                  await supabase.from('Profile').insert({
                    'user_id': user.id,
                    'name': nameController.text.trim(),
                    'is_patient': isPatient,
                  });

                  // 3️⃣ If patient, create identity row (auto-generates code)
                  if (isPatient == true) {
                    await supabase.from('PatientCode').insert({
                      'patient_id': user.id,
                    });
                  }

                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sign up failed: $e')),
                  );
                }
              },
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}


// ---  VITALS STATE MANAGEMENT WIDGET ---
class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  // Mock In-Memory Data Store for Vitals
  List<Vital> _vitals = [
    Vital(id: 'v1', name: 'Blood Pressure', normalRange: '90-120/60-80 mmHg', unit: 'mmHg', icon: Icons.favorite, iconColor: const Color(0xFFE57373)), // Red
    Vital(id: 'v2', name: 'Heart Rate', normalRange: '60-100 bpm', unit: 'bpm', icon: Icons.monitor_heart, iconColor: const Color(0xFF64B5F6)), // Blue
    Vital(id: 'v3', name: 'Temperature', normalRange: '97.0-99.0 °F', unit: '°F', icon: Icons.thermostat, iconColor: const Color(0xFFFFB74D)), // Orange
  ];
  
  List<VitalTimeslot> _timeslots = [
    const VitalTimeslot(id: 't1', label: 'Morning (7:00 AM)'),
    const VitalTimeslot(id: 't2', label: 'Evening (9:00 PM)'),
  ];

  // Placeholder for latest readings
  List<VitalReading> _readings = [
    VitalReading(id: 'r1', vitalId: 'v1', value: 120.0, timestamp: DateTime.now().subtract(const Duration(hours: 2)), systolic: 125, diastolic: 85, unit: 'mmHg'),
    VitalReading(id: 'r2', vitalId: 'v2', value: 75.0, timestamp: DateTime.now().subtract(const Duration(hours: 2)), unit: 'bpm'),
  ];

  // --- CRUD METHODS (Simplifed in-memory for now) ---
  void _addVital(Vital vital) {
    setState(() {
      // Simple mock ID generation
      final newId = 'v${_vitals.length + 1}';
      _vitals.add(vital.copyWith(id: newId));
    });
  }

  void _updateVital(String id, Vital updatedVital) {
    setState(() {
      _vitals = _vitals.map((v) => v.id == id ? updatedVital : v).toList();
    });
  }

  void _deleteVital(String id) {
    setState(() {
      _vitals.removeWhere((v) => v.id == id);
    });
  }

  void _addReading(VitalReading reading) {
    setState(() {
      _readings.add(reading);
    });
  }

  void _addTimeslot(VitalTimeslot slot) {
    setState(() {
      final newId = 't${_timeslots.length + 1}';
      _timeslots.add(VitalTimeslot(id: newId, label: slot.label));
    });
  }

  void _deleteTimeslot(String id) {
    setState(() {
      _timeslots.removeWhere((t) => t.id == id);
    });
  }
@override
  Widget build(BuildContext context) {
    // Determine the latest reading for each vital type
    final Map<String, VitalReading> latestReadingsMap = {};
    for (var reading in _readings) {
      // Only keep the most recent reading for each vitalId
      if (!latestReadingsMap.containsKey(reading.vitalId) || reading.timestamp.isAfter(latestReadingsMap[reading.vitalId]!.timestamp)) {
        latestReadingsMap[reading.vitalId!] = reading;
      }
    }
    
    // Combine the Vital model with its latest reading for the VitalsPage
    final List<Map<String, dynamic>> vitalDataForPage = _vitals.map((vital) {
      final latestReading = latestReadingsMap[vital.id];
      
      // Default values if no reading exists
      String currentValue = latestReading?.systolic != null 
          ? '${latestReading!.systolic}/${latestReading.diastolic}' 
          : latestReading?.value.toStringAsFixed(1) ?? '--';
      String unit = latestReading?.unit ?? vital.unit;
      String timeAgo = latestReading != null 
          ? 'Log at ${latestReading.timestamp.hour}:${latestReading.timestamp.minute.toString().padLeft(2, '0')}' 
          : 'No recent reading';

      return {
        'id': vital.id,
        'title': vital.name,
        'normalRange': vital.normalRange,
        'currentValue': currentValue,
        'unit': unit,
        'timeAgo': timeAgo,
        'icon': vital.icon,
        'iconColor': vital.iconColor,
      };
    }).toList();


    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vitals'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Latest Readings'),
              Tab(text: 'Configuration'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Vitals Page (The Dashboard/Timeline)
            VitalsPage(
              vitalData: vitalDataForPage,
              vitals: _vitals,
              timeslots: _timeslots,
              addReading: _addReading,
              addTimeslot: _addTimeslot,
            ),
            // Tab 2: Vitals Configuration Page
            VitalsConfigPage(
              vitals: _vitals,
              addVital: _addVital,
              deleteVital: _deleteVital,
              updateVital: _updateVital,
              timeslots: _timeslots,
              addTimeslot: _addTimeslot,
              deleteTimeslot: _deleteTimeslot,
            ),
          ],
        ),
      ),
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
    const VitalsScreen(),
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
