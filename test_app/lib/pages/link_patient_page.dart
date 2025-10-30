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

   // Fixed 12-color caregiver palette
  static const colorPalette = [
    '#4A90E2', // Blue
    '#7ED321', // Green
    '#D0021B', // Red
    '#F5A623', // Orange
    '#9013FE', // Purple
    '#50E3C2', // Teal
    '#FF6F61', // Pink
    '#00BCD4', // Cyan
    '#CDDC39', // Lime
    '#3F51B5', // Indigo
    '#FFC107', // Amber
    '#795548', // Brown
  ];

  Future<String> _assignUniqueColor(String patientId) async {
    final supabase = Supabase.instance.client;

    // Get all caregiver IDs linked to this patient
    final existingCaregivers = await supabase
        .from('CareRelation')
        .select('user_id')
        .eq('patient_id', patientId);

    // Fetch colors already used
    final caregiverIds =
        existingCaregivers.map((row) => row['user_id']).whereType<String>().toList();

    final usedColorsResponse = caregiverIds.isEmpty
        ? []
        : await supabase
            .from('Profile')
            .select('color')
            .inFilter('user_id', caregiverIds);

    final usedColors = usedColorsResponse
        .map((row) => row['color'])
        .whereType<String>()
        .toSet();

    // Pick a color not already used
    final availableColors =
        colorPalette.where((c) => !usedColors.contains(c)).toList();

    if (availableColors.isEmpty) {
      // fallback if all 12 are taken
      availableColors.addAll(colorPalette);
    }

    availableColors.shuffle();
    return availableColors.first;
  }

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
      
      // Assign unique color for this caregiver
      final color = await _assignUniqueColor(patient['patient_id']);

      await supabase
          .from('Profile')
          .update({'color': color})
          .eq('user_id', userId);

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
        automaticallyImplyLeading: false, // removes back arrow
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
