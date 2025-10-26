import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class LinkPatientPage extends StatefulWidget {
  const LinkPatientPage({super.key});

  @override
  State<LinkPatientPage> createState() => _LinkPatientPageState();
}

class _LinkPatientPageState extends State<LinkPatientPage> {
  final codeController = TextEditingController();
  bool isLoading = false;

  Future<void> _linkPatient() async {
    setState(() => isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // Look up patient_id by share code
      final patient = await supabase
          .from('PatientCode')
          .select('patient_id')
          .eq('code', codeController.text.trim())
          .maybeSingle();

      if (patient == null) {
        throw Exception('Invalid share code');
      }

      // Insert care relation
      await supabase.from('CareRelation').insert({
        'user_id': userId,
        'patient_id': patient['patient_id'],
      });

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error linking patient: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // 🚫 removes back arrow
        title: const Text('Link Patient'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter your patient\'s share code to link accounts:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Share Code'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _linkPatient,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Link Patient'),
            ),
          ],
        ),
      ),
    );
  }
}
