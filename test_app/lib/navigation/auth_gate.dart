// lib/navigation/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/link_patient_page.dart';
import '../main.dart';
// import '../pages/calendar_page.dart'; 

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
