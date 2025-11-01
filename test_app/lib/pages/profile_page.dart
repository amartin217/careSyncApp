import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  Future<void> _confirmLogout(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await supabase.auth.signOut();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }


  IconData _iconForSection(String title) {
    switch (title) {
      case 'Basic Info':
        return Icons.person_outline;
      case 'Patient Details':
        return Icons.favorite_outline;
      case 'Caregivers':
        return Icons.group_outlined;
      case 'Linked Patient':
        return Icons.health_and_safety_outlined;
      case 'Other Caregivers':
        return Icons.people_outline;
      default:
        return Icons.folder_open;
    }
  }

  Future<void> _fetchProfileData() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser!;
    try {
      final profile = await supabase
          .from('Profile')
          .select('name, is_patient')
          .eq('user_id', user.id)
          .single();

      String? patientName;
      String? shareCode;
      List<String> caregiverNames = [];

      if (profile['is_patient'] == true) {
        // 🧩 PATIENT VIEW
        final codeRes = await supabase
            .from('PatientCode')
            .select('code')
            .eq('patient_id', user.id)
            .maybeSingle();
        shareCode = codeRes?['code'];

        // Get all caregivers linked to this patient
        final caregiversRes = await supabase
            .from('CareRelation')
            .select('user_id')
            .eq('patient_id', user.id);

        final caregiverIds = caregiversRes
            .map((r) => r['user_id'])
            .whereType<String>()
            .toList();

        if (caregiverIds.isNotEmpty) {
          final caregivers = await supabase
              .from('Profile')
              .select('name')
              .inFilter('user_id', caregiverIds);
          caregiverNames =
              caregivers.map<String>((c) => c['name'] as String).toList();
        }
      } else {
        // 🧩 CAREGIVER VIEW
        final relation = await supabase
            .from('CareRelation')
            .select('patient_id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (relation != null) {
          final patientId = relation['patient_id'];

          final patientProfile = await supabase
              .from('Profile')
              .select('name')
              .eq('user_id', patientId)
              .maybeSingle();
          patientName = patientProfile?['name'];

          final codeRes = await supabase
              .from('PatientCode')
              .select('code')
              .eq('patient_id', patientId)
              .maybeSingle();
          shareCode = codeRes?['code'];

          final otherCaregivers = await supabase
              .from('CareRelation')
              .select('user_id')
              .eq('patient_id', patientId);
          final caregiverIds = otherCaregivers
              .map((r) => r['user_id'])
              .whereType<String>()
              .where((id) => id != user.id)
              .toList();

          if (caregiverIds.isNotEmpty) {
            final caregivers = await supabase
                .from('Profile')
                .select('name')
                .inFilter('user_id', caregiverIds);
            caregiverNames =
                caregivers.map<String>((c) => c['name'] as String).toList();
          }
        }
      }

      setState(() {
        profileData = {
          'name': profile['name'],
          'is_patient': profile['is_patient'],
          'patientName': patientName,
          'shareCode': shareCode,
          'caregivers': caregiverNames,
        };
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      shadowColor: Colors.deepPurple.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity, // ✅ full width card
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconForSection(title), color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children.map((w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: w,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileSheet() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser!;
    final nameController = TextEditingController(text: profileData?['name']);
    final passwordController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Wrap(
            children: [
              const Center(
                child: Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  hintText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                onChanged: (_) => setModalState(() {}), // <-- use modal state
              ),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final pw = passwordController.text;
                if (pw.isEmpty) return const SizedBox.shrink();
                final meetsRequirement = pw.length >= 6;
                return Row(
                  children: [
                    Icon(
                      meetsRequirement ? Icons.check_circle : Icons.error,
                      color: meetsRequirement ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      meetsRequirement
                          ? 'Password meets requirements'
                          : 'Password must be at least 6 characters',
                      style: TextStyle(
                        color: meetsRequirement ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),            ElevatedButton(
              onPressed: () async {
                try {
                  // Update name in Profile table
                  await supabase
                      .from('Profile')
                      .update({'name': nameController.text})
                      .eq('user_id', user.id);

                  // Update password if provided
                  if (passwordController.text.isNotEmpty) {
                    await supabase.auth.updateUser(
                      UserAttributes(password: passwordController.text),
                    );
                  }

                  Navigator.pop(context);
                  _fetchProfileData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating profile: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Changes'),
            ),
            const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.deepPurple, // 💜 Match Dashboard color
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : profileData == null
              ? const Center(child: Text('No profile data found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCard('Basic Info', [
                        Text('Name: ${profileData!['name']}',
                            style: const TextStyle(fontSize: 16)),
                        Text(
                            'Role: ${profileData!['is_patient'] == true ? "Patient" : "Caregiver"}',
                            style: const TextStyle(fontSize: 16)),
                      ]),
                      if (profileData!['is_patient'] == true) ...[
                        _buildCard('Patient Details', [
                          Text(
                              'Share Code: ${profileData!['shareCode'] ?? "N/A"}',
                              style: const TextStyle(fontSize: 16)),
                        ]),
                        _buildCard('Caregivers', [
                          if (profileData!['caregivers'].isEmpty)
                            const Text('No caregivers linked yet.')
                          else
                            ...profileData!['caregivers']
                                .map<Widget>((c) => Text('• $c',
                                    style: const TextStyle(fontSize: 15)))
                                .toList(),
                        ]),
                      ] else ...[
                        _buildCard('Linked Patient', [
                          Text(
                              'Patient: ${profileData!['patientName'] ?? "N/A"}',
                              style: const TextStyle(fontSize: 16)),
                          Text(
                              'Patient Code: ${profileData!['shareCode'] ?? "N/A"}',
                              style: const TextStyle(fontSize: 16)),
                        ]),
                        _buildCard('Other Caregivers', [
                          if (profileData!['caregivers'].isEmpty)
                            const Text('No other caregivers linked.')
                          else
                            ...profileData!['caregivers']
                                .map<Widget>((c) => Text('• $c',
                                    style: const TextStyle(fontSize: 15)))
                                .toList(),
                        ]),
                      ],
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _showEditProfileSheet,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            'Log Out',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _confirmLogout(context),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

