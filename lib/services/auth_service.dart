import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  UserModel? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return UserModel(id: user.id, email: user.email ?? '');
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = res.user;
    if (user == null) {
      throw const AuthException('Login failed: no user returned');
    }

    return UserModel(id: user.id, email: user.email ?? email);
  }

  Future<UserModel> register({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signUp(email: email, password: password);

    final user = res.user;
    if (user == null) {
      throw const AuthException('Register failed: no user returned');
    }

    return UserModel(id: user.id, email: user.email ?? email);
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }
}
