// lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _profile;

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;

  Future<void> loadUser() async {
    final supabase = Supabase.instance.client;
    _user = supabase.auth.currentUser;

    if (_user != null) {
      final res = await supabase
          .from('Profile')
          .select('*')
          .eq('user_id', _user!.id)
          .maybeSingle();

      _profile = res;
    }

    notifyListeners();
  }

  bool get isPatient => _profile?['is_patient'] == true;
  String? get userId => _user?.id;
}
