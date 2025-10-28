import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'link_patient_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<Map<String, dynamic>?> _fetchUserProfile() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final profile = await supabase
        .from('Profile')
        .select('user_id, is_patient')
        .eq('user_id', userId)
        .maybeSingle();

    if (profile == null) return null;

    // If patient, also fetch their share code
    if (profile['is_patient'] == true) {
      final patientCode = await supabase
          .from('PatientCode')
          .select('code')
          .eq('patient_id', userId)
          .maybeSingle();
      return {
        'is_patient': true,
        'code': patientCode?['code'],
      };
    } else {
      // Caregiver — check if they already have a linked patient
      final relation = await supabase
          .from('CareRelation')
          .select('patient_id')
          .eq('user_id', userId)
          .maybeSingle();
      return {
        'is_patient': false,
        'has_patient_linked': relation != null,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchUserProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!;
        // Always just show dashboard content in this page
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text("Dashboard"),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['is_patient'] == true) ...[
                  Text(
                    "Your Share Code:",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    data['code'] ?? 'No code found',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                ],
                _buildDashboardContent(context),
              ],
            ),
          ),
        );
      }
    );
  }
 

  Widget _buildDashboardContent(BuildContext context) {
    return Card(
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Upcoming Today",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.local_hospital, color: Colors.blue),
              title: const Text("Aspirin - 81mg"),
              subtitle: const Text("2:00 PM"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ],
        ),
      ),
    );
  }

}
