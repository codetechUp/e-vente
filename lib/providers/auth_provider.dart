import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_model.dart';
import '../models/user_model.dart';
import '../services/app_users_service.dart';
import '../services/auth_service.dart';

enum UserRole { admin, client, livreur, preparateur, commercial }

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
  bool get isCommercial => _role == UserRole.commercial;

  Future<void> _loadRole() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    final uid = authUser?.id;
    final email = authUser?.email;
    final rawPhone = authUser?.phone ?? '';
    final phone = _normalizePhone(rawPhone.isNotEmpty ? rawPhone : '');
    if (uid == null) return;

    try {
      // Passer le téléphone pour que _ensureCurrentUserRow puisse lier les comptes pré-enregistrés
      await _ensureCurrentUserRow();

      Map<String, dynamic>? row = await Supabase.instance.client
          .from('users')
          .select('role_id, roles(name)')
          .eq('id', uid)
          .maybeSingle();

      if (kDebugMode) {
        debugPrint('[AuthProvider] _loadRole uid=$uid phone=$phone email=$email');
        debugPrint('[AuthProvider] users row=$row');
      }

      // Fallback par email
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

      // Fallback par téléphone (connexion OTP - compte pré-enregistré non encore lié)
      if (row == null && phone.isNotEmpty) {
        row = await Supabase.instance.client
            .from('users')
            .select('role_id, roles(name), phone, id')
            .eq('phone', phone)
            .maybeSingle();
        if (kDebugMode) {
          debugPrint('[AuthProvider] fallback user lookup by phone=$phone row=$row');
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
        case 'commercial':
          _role = UserRole.commercial;
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
    String? referrerId,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      await _authService.register(email: email, password: password);
      await _ensureCurrentUserRow(referrerId: referrerId);
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

  Future<bool> sendOtp({required String phone}) async {
    final normalizedPhone = _normalizePhone(phone);
    _setLoading(true);
    _error = null;
    try {
      if (kDebugMode) {
        debugPrint('[AuthProvider] sendOtp start phone=$normalizedPhone');
      }

      // Vérifier d'abord si le numéro de téléphone est pré-enregistré
      // En cas d'erreur de l'appel RPC (fonction non déployée, réseau...), on laisse passer.
      try {
        final dynamic checkRes = await Supabase.instance.client
            .rpc('check_phone_registered', params: {'phone_to_check': normalizedPhone});
        
        if (kDebugMode) {
          debugPrint('[AuthProvider] check_phone_registered result=$checkRes (${checkRes.runtimeType})');
        }

        // On bloque uniquement si la RPC répond explicitement false (booléen)
        // null = RPC non déployée ou erreur → on laisse passer
        if (checkRes == false) {
          _error = "Ce numéro de téléphone n'est pas pré-enregistré. Veuillez contacter un commercial.";
          if (kDebugMode) {
            debugPrint('[AuthProvider] sendOtp blocked: phone not registered');
          }
          notifyListeners();
          return false;
        }
      } catch (rpcErr) {
        if (kDebugMode) {
          debugPrint('[AuthProvider] rpc check_phone_registered error=$rpcErr (will pass through)');
        }
        // Si erreur réseau, on bloque immédiatement
        final errStr = rpcErr.toString().toLowerCase();
        if (errStr.contains('socketexception') || 
            errStr.contains('failed host lookup') ||
            errStr.contains('network')) {
          _error = 'Pas de connexion internet. Vérifie ton réseau et réessaie.';
          notifyListeners();
          return false;
        }
        // Autres erreurs (ex: fonction RPC non encore déployée) → on laisse passer
      }

      await _authService.sendOtp(phone: normalizedPhone);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapAuthError(e, fallback: 'Envoi du code échoué. Réessaie.');
      if (kDebugMode) {
        debugPrint('[AuthProvider] sendOtp error=$e');
      }
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyOtp({
    required String phone, 
    required String token,
    String? name,
    String? adresse,
    String? referrerId,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    _setLoading(true);
    _error = null;
    try {
      if (kDebugMode) {
        debugPrint('[AuthProvider] verifyOtp start phone=$normalizedPhone');
      }
      await _authService.verifyOtp(phone: normalizedPhone, token: token);
      
      await _ensureCurrentUserRow(referrerId: referrerId);

      if (name != null || adresse != null) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          final updates = <String, dynamic>{};
          if (name != null && name.trim().isNotEmpty) {
            updates['name'] = name.trim();
            updates['nom'] = name.trim();
          }
          if (adresse != null && adresse.trim().isNotEmpty) {
            updates['adresse'] = adresse.trim();
          }
          if (updates.isNotEmpty) {
            await _usersService.updateById(currentUser.id, updates);
          }
        }
      }

      await _loadRole();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapAuthError(e, fallback: 'Vérification échouée. Code incorrect ?');
      if (kDebugMode) {
        debugPrint('[AuthProvider] verifyOtp error=$e');
      }
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

  Future<void> _ensureCurrentUserRow({String? referrerId}) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    // Normaliser le numéro de téléphone retourné par Supabase Auth
    final rawPhone = currentUser.phone ?? currentUser.userMetadata?['phone'] as String? ?? '';
    final phoneStr = _normalizePhone(rawPhone.isNotEmpty ? rawPhone : '').isEmpty == false
        ? _normalizePhone(rawPhone)
        : rawPhone;

    if (kDebugMode) {
      debugPrint('[AuthProvider] _ensureCurrentUserRow authId=${currentUser.id} phone=$phoneStr');
    }

    // 1. Chercher s'il y a déjà un compte pré-enregistré (id différent de currentUser.id)
    AppUserModel? preregistered;
    if (phoneStr.isNotEmpty) {
      preregistered = await _usersService.getByPhone(phoneStr);
    }
    if (preregistered == null && currentUser.email != null && currentUser.email!.isNotEmpty) {
      preregistered = await _usersService.getByEmail(currentUser.email!);
    }

    if (kDebugMode) {
      debugPrint('[AuthProvider] preregistered=${preregistered?.id} currentUser.id=${currentUser.id}');
    }

    if (preregistered != null && preregistered.id != currentUser.id) {
      if (kDebugMode) {
        debugPrint('[AuthProvider] Found pre-registered user to claim: id=${preregistered.id} phone=${preregistered.phone}');
      }
      
      // Si une ligne existe déjà avec currentUser.id (insérée par le trigger), on la supprime pour pouvoir mettre à jour le compte pré-enregistré
      final duplicate = await _usersService.getById(currentUser.id);
      if (duplicate != null) {
        try {
          await _usersService.deleteById(currentUser.id);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AuthProvider] Error deleting trigger-inserted duplicate: $e');
          }
        }
      }

      // On met à jour l'identifiant du compte pré-enregistré pour le lier à Supabase Auth
      try {
        final Map<String, dynamic> updatePayload = {'id': currentUser.id};

        // Ne mettre à jour l'email que si c'est un vrai email non vide
        final newEmail = currentUser.email?.trim() ?? '';
        final existingEmail = preregistered.email?.trim() ?? '';
        if (newEmail.isNotEmpty && newEmail != existingEmail) {
          updatePayload['email'] = newEmail;
        }
        // Ne jamais envoyer une chaîne vide pour l'email (contrainte unique)

        if (referrerId != null && preregistered.referrerId == null) {
          updatePayload['referrer_id'] = referrerId;
        }

        await Supabase.instance.client
            .from('users')
            .update(updatePayload)
            .eq('id', preregistered.id!);
        return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthProvider] Error claiming pre-registered user: $e');
        }
        return;
      }
    }

    // 2. Si aucun compte pré-enregistré avec un ID différent n'est trouvé, on vérifie si la ligne avec currentUser.id existe déjà
    final existing = await _usersService.getById(currentUser.id);
    if (existing != null) {
      final rawEmail = currentUser.email?.trim() ?? '';
      final emailStr = rawEmail.isEmpty ? phoneStr : rawEmail;

      final updates = <String, dynamic>{};
      if (emailStr.isNotEmpty && emailStr != existing.email) {
        updates['email'] = emailStr;
      }
      if (referrerId != null && existing.referrerId == null) {
        updates['referrer_id'] = referrerId;
      }
      if (updates.isNotEmpty) {
        await _usersService.updateById(currentUser.id, updates);
      }
      return;
    }

    // 3. Si aucune ligne n'existe, on la crée
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

    final rawEmail = currentUser.email?.trim() ?? '';
    final emailStr = rawEmail.isEmpty ? phoneStr : rawEmail;

    await _usersService.create(
      AppUserModel(
        id: currentUser.id,
        email: emailStr,
        name:
            (currentUser.userMetadata?['name'] as String?)?.trim().isEmpty ??
                true
            ? null
            : (currentUser.userMetadata?['name'] as String?),
        phone: currentUser.phone ?? currentUser.userMetadata?['phone'] as String?,
        roleId: clientRoleId,
        isActive: true,
        referrerId: referrerId,
      ),
    );
  }

  String _mapAuthError(Object error, {required String fallback}) {
    final raw = error.toString().toLowerCase();

    // Intercepter d'abord les erreurs de base de données (lorsque le trigger lève une exception)
    if (raw.contains('database error saving new user') || 
        raw.contains('unexpected_failure') || 
        raw.contains('database error')) {
      return "Ce numéro de téléphone n'est pas pré-enregistré. Veuillez contacter un commercial.";
    }

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

    if (raw.contains('failed host lookup') ||
        raw.contains('socketexception') ||
        raw.contains('authretryablefetchexception') ||
        raw.contains('clientexception') ||
        raw.contains('network')) {
      return 'Pas de connexion internet. Vérifie ton réseau et réessaie.';
    }

    return fallback;
  }

  String _normalizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 9) {
      cleaned = '221$cleaned';
    } else if (cleaned.length == 14 && cleaned.startsWith('00221')) {
      cleaned = cleaned.substring(2);
    }
    return '+$cleaned';
  }
}

extension UserAvatarExtension on User {
  String get avatarLetter {
    final name = userMetadata?['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim()[0].toUpperCase();
    
    final nom = userMetadata?['nom'] as String?;
    if (nom != null && nom.trim().isNotEmpty) return nom.trim()[0].toUpperCase();
    
    if (email != null && email!.trim().isNotEmpty) return email!.trim()[0].toUpperCase();
    
    final phoneNum = phone?.replaceAll('+221', '').trim();
    if (phoneNum != null && phoneNum.isNotEmpty) return phoneNum[0].toUpperCase();
    
    return '?';
  }
}
