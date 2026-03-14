import '../models/user_model.dart';

class AuthService {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  Future<UserModel> login({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _currentUser = UserModel(id: 'local_user', email: email);
    return _currentUser!;
  }

  Future<UserModel> register({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _currentUser = UserModel(id: 'local_user', email: email);
    return _currentUser!;
  }

  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _currentUser = null;
  }
}
