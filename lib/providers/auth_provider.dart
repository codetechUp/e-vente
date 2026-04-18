import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_model.dart';
import '../models/user_model.dart';
import '../services/app_users_service.dart';
import '../services/auth_service.dart';

enum UserRole { admin, client, livreur, preparateur }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final AppUsersService _usersService;
  late final StreamSubscription<AuthState> _authSubscription;

  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService(),
      _usersService = AppUsersService() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) {
      if (kDebugMode) {
        debugPrint(
          '[AuthProvider] onAuthStateChange: event=${event.event}, uid=${event.session?.user.id}, email=${event.session?.user.email}',
        );
      }
      if (event.session != null) {
        _loadRole();
      } else {
        _role = null;
        _roleName = null;
      }
      notifyListeners();
    });
    // Load role on startup if already logged in
    if (_authService.currentUser != null) {
      _loadRole();
    }
  }

  UserModel? get user => _authService.currentUser;

  UserRole? _role;
  UserRole? get role => _role;

  String? _roleName;
  String? get roleName => _roleName;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  bool get isAdmin => _role == UserRole.admin;
  bool get isClient => _role == UserRole.client;
  bool get isLivreur => _role == UserRole.livreur;
  bool get isPreparateur => _role == UserRole.preparateur;

  Future<void> _loadRole() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (uid == null) return;

    try {
      Map<String, dynamic>? row = await Supabase.instance.client
          .from('users')
          .select('role_id, roles(name)')
          .eq('id', uid)
          .maybeSingle();

      if (kDebugMode) {
        debugPrint('[AuthProvider] _loadRole uid=$uid');
        debugPrint('[AuthProvider] _loadRole email=$email');
        debugPrint('[AuthProvider] users row=$row');
      }

      if (row == null && email != null && email.isNotEmpty) {
        row = await Supabase.instance.client
            .from('users')
            .select('role_id, roles(name), email, id')
            .eq('email', email)
            .maybeSingle();
        if (kDebugMode) {
          debugPrint('[AuthProvider] fallback user lookup by email row=$row');
        }
      }

      if (row == null) {
        _role = UserRole.client;
        _roleName = 'client';
        if (kDebugMode) {
          debugPrint('[AuthProvider] no user row found, fallback role=client');
        }
        notifyListeners();
        return;
      }

      final rolesData = row['roles'];
      String? name;

      if (rolesData is Map) {
        name = (rolesData['name'] as String?)?.toLowerCase().trim();
      } else if (rolesData is List && rolesData.isNotEmpty) {
        final first = rolesData.first;
        if (first is Map) {
          name = (first['name'] as String?)?.toLowerCase().trim();
        }
      }

      if (name == null) {
        final roleId = row['role_id'] as int?;
        if (roleId != null) {
          final roleRow = await Supabase.instance.client
              .from('roles')
              .select('name')
              .eq('id', roleId)
              .maybeSingle();
          if (kDebugMode) {
            debugPrint(
              '[AuthProvider] fallback role lookup role_id=$roleId roleRow=$roleRow',
            );
          }
          if (roleRow != null) {
            name = (roleRow['name'] as String?)?.toLowerCase().trim();
          }
        }
      }

      _roleName = name;
      switch (name) {
        case 'admin':
        case 'administrateur':
          _role = UserRole.admin;
          break;
        case 'livreur':
          _role = UserRole.livreur;
          break;
        case 'preparateur':
        case 'préparateur':
          _role = UserRole.preparateur;
          break;
        default:
          _role = UserRole.client;
      }
      if (kDebugMode) {
        debugPrint(
          '[AuthProvider] role resolved: roleName=$_roleName enum=$_role isAdmin=$isAdmin isClient=$isClient isLivreur=$isLivreur',
        );
      }
      notifyListeners();
    } catch (e) {
      _role = UserRole.client;
      _roleName = 'client';
      if (kDebugMode) {
        debugPrint('[AuthProvider] _loadRole error=$e');
      }
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _error = null;
    try {
      if (kDebugMode) {
        debugPrint('[AuthProvider] login start email=$email');
      }
      await _authService.login(email: email, password: password);
      if (kDebugMode) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        debugPrint(
          '[AuthProvider] login success uid=${currentUser?.id} email=${currentUser?.email}',
        );
      }
      await _loadRole();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapAuthError(e, fallback: 'Connexion échouée. Réessaie.');
      if (kDebugMode) {
        debugPrint('[AuthProvider] login error=$e');
      }
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
      await _ensureCurrentUserRow();
      await _loadRole();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapAuthError(
        e,
        fallback: 'Création de compte échouée. Réessaie.',
      );
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
      if (kDebugMode) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        debugPrint(
          '[AuthProvider] logout uid=${currentUser?.id} email=${currentUser?.email}',
        );
      }
      await _authService.logout();
      _role = null;
      _roleName = null;
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

  Future<void> _ensureCurrentUserRow() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final existing = await _usersService.resolveForAuthUser(
      authUserId: currentUser.id,
      email: currentUser.email,
    );
    if (existing != null) {
      if (existing.id != currentUser.id) return;

      await _usersService.updateById(currentUser.id, {
        'email': currentUser.email ?? existing.email,
      });
      return;
    }

    final email = currentUser.email?.trim();
    if (email == null || email.isEmpty) return;

    int? clientRoleId;
    try {
      final roles = await Supabase.instance.client
          .from('roles')
          .select('id')
          .eq('name', 'client')
          .maybeSingle();

      if (roles != null) {
        clientRoleId = roles['id'] as int?;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthProvider] Error fetching client role: $e');
      }
    }

    await _usersService.create(
      AppUserModel(
        id: currentUser.id,
        email: email,
        name:
            (currentUser.userMetadata?['name'] as String?)?.trim().isEmpty ??
                true
            ? null
            : (currentUser.userMetadata?['name'] as String?),
        phone: currentUser.userMetadata?['phone'] as String?,
        roleId: clientRoleId,
        isActive: true,
      ),
    );
  }

  String _mapAuthError(Object error, {required String fallback}) {
    if (error is AuthRetryableFetchException) {
      return 'Pas de connexion internet. Vérifie ton réseau et réessaie.';
    }

    if (error is SocketException) {
      return 'Pas de connexion internet. Vérifie ton réseau et réessaie.';
    }

    if (error is AuthException) {
      final message = error.message.toLowerCase();

      if (message.contains('invalid login credentials')) {
        return 'Email ou mot de passe incorrect.';
      }

      if (message.contains('failed host lookup') ||
          message.contains('socketexception') ||
          message.contains('network') ||
          message.contains('connection')) {
        return 'Pas de connexion internet. Vérifie ton réseau et réessaie.';
      }

      if (error.message.trim().isNotEmpty) {
        return error.message;
      }
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('failed host lookup') ||
        raw.contains('socketexception') ||
        raw.contains('authretryablefetchexception') ||
        raw.contains('clientexception') ||
        raw.contains('network')) {
      return 'Pas de connexion internet. Vérifie ton réseau et réessaie.';
    }

    return fallback;
  }
}
