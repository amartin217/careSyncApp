// lib/main.dart
import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/medication_page.dart';
import 'pages/vitals_page.dart';
import 'pages/calendar_page.dart';
import 'pages/messaging_page.dart';
import 'pages/link_patient_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'pages/vitals_config_page.dart'; // Vitals Configuration Tab
import 'models/vitals_data_models.dart'; // VitalType, VitalReading
import 'models/vital_timeslot.dart';
import '../widgets/profile_menu.dart';


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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C7C9D), // muted steel blue
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F6F8), // soft gray-blue background
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF1E2D3D),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E2D3D),
          ),
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color:Colors.white,
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C8DA7), // soft blue-gray
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.black38),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF2E3A4A)),
        ),
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



class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final Uuid uuid = const Uuid();

  // Initial Placeholder VitalTypes (with IDs)
  // These IDs are used to link the readings to the type
  final String bpVitalId = const Uuid().v4();
  final String hrVitalId = const Uuid().v4();

  late List<VitalType> _configuredVitals;
  late List<VitalReading> _readings;
  late List<VitalTimeslot> _timeslots;

  @override
  void initState() {
    super.initState();
    // Initialize Vitals and Readings
    _configuredVitals = [
      VitalType(id: bpVitalId, name: 'Blood Pressure', normalRange: '120/80', unit: 'mmHg'),
      VitalType(id: hrVitalId, name: 'Heart Rate', normalRange: '60-100', unit: 'BPM'),
      VitalType(id: const Uuid().v4(), name: 'Temperature', normalRange: '97.6-99.6', unit: '°F'),
    ];

    // Initialize Readings (FIX: Use vitalId instead of vitalName/type)
    _readings = [
      VitalReading(
        id: uuid.v4(),
        vitalId: bpVitalId, // FIX: Use vitalId
        value: '125/82',
        unit: 'mmHg',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      VitalReading(
        id: uuid.v4(),
        vitalId: hrVitalId, // FIX: Use vitalId
        value: '75',
        unit: 'BPM',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];

    // Initialize Timeslots
    _timeslots = [
      VitalTimeslot(id: uuid.v4(), label: 'Morning', time: const TimeOfDay(hour: 8, minute: 0)),
      VitalTimeslot(id: uuid.v4(), label: 'Evening', time: const TimeOfDay(hour: 18, minute: 0)),
    ];
  }

  // --- VitalType Management Functions ---
  void _addVital(VitalType vital) {
    setState(() {
      _configuredVitals = [..._configuredVitals, vital];
    });
  }

  void _updateVital(String id, VitalType updatedVital) {
    setState(() {
      _configuredVitals = _configuredVitals.map((v) => v.id == id ? updatedVital : v).toList();
    });
  }

  void _deleteVital(String id) {
    setState(() {
      _configuredVitals.removeWhere((v) => v.id == id);
      // Also remove readings associated with the deleted vital
      _readings.removeWhere((r) => r.vitalId == id);
    });
  }

  // --- VitalReading Management Functions ---
  void _addReading(VitalReading reading) {
    setState(() {
      _readings = [..._readings, reading];
    });
  }

  // --- VitalTimeslot Management Functions ---
  void _addTimeslot(VitalTimeslot slot) {
    setState(() {
      _timeslots = [..._timeslots, slot];
    });
  }

  void _updateTimeslot(String id, VitalTimeslot updatedSlot) { // FIX: Added _updateTimeslot
    setState(() {
      _timeslots = _timeslots.map((s) => s.id == id ? updatedSlot : s).toList();
    });
  }

  void _deleteTimeslot(String id) {
    setState(() {
      _timeslots.removeWhere((s) => s.id == id);
    });
  }

 
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vitals'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Vitals', icon: Icon(Icons.favorite_border)),
              Tab(text: 'Configuration', icon: Icon(Icons.settings)),
            ],
          ),
          actions: [const ProfileMenuButton()],
        ),
        body: TabBarView(
          children: [
            // My Vitals Page (Summary & Timeline)
            VitalsPage(
              configuredVitals: _configuredVitals,
              readings: _readings,
              addReading: _addReading, // FIX: Corrected parameter name from onAddReading
            ),
            // Configuration Page
            VitalsConfigPage(
              configuredVitals: _configuredVitals,
              onAddVital: _addVital,
              onDeleteVital: _deleteVital,
              onUpdateVital: _updateVital,
              timeslots: _timeslots,
              onAddTimeslot: _addTimeslot,
              onDeleteTimeslot: _deleteTimeslot,
              onUpdateTimeslot: _updateTimeslot, // FIX: Added required parameter
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