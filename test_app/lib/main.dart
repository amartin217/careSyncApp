// lib/main.dart
import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/medication_page.dart';
import 'pages/vitals_page.dart';
import 'pages/calendar_page.dart';
import 'pages/messaging_page.dart';
import 'pages/link_patient_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'pages/user_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kslxhihlmviquoetrpjh.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzbHhoaWhsbXZpcXVvZXRycGpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5NDAxMTcsImV4cCI6MjA3NTUxNjExN30.g1yYb5JHMIvN6DHdw0WQ_TAAyWL-oEHTEPazZukoGjc',
  );
  // runApp(const CaregiverSupportApp());
  runApp(
    ChangeNotifierProvider(
      create: (_) => UserProvider()..loadUser(), // load user once at start
      child: const CaregiverSupportApp(),
    ),
  );
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
