import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  late final StreamSubscription<AuthState> _authSubscription;

  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      notifyListeners();
    });
  }

  UserModel? get user => _authService.currentUser;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _error = null;
    try {
      await _authService.login(email: email, password: password);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      await _authService.register(email: email, password: password);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    _error = null;
    try {
      await _authService.logout();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
