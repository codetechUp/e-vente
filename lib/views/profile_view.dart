import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_model.dart';
import '../services/app_users_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _usersService = AppUsersService();

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _adresse = TextEditingController();

  bool _loading = false;
  bool _initLoading = true;
  AppUserModel? _profile;
  String? _error;

  String get _authUserId => Supabase.instance.client.auth.currentUser?.id ?? '';
  String get _authEmail =>
      Supabase.instance.client.auth.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _adresse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _initLoading = true;
      _error = null;
    });

    try {
      final id = _authUserId;
      if (id.isEmpty) {
        throw StateError('Utilisateur non connecté');
      }

      final userRow = await _usersService.resolveForAuthUser(
        authUserId: id,
        email: _authEmail,
      );

      if (userRow == null) {
        throw StateError('Profil introuvable dans la table users');
      }

      _profile = userRow;
      _name.text = (userRow.name ?? userRow.nom ?? '').trim();
      _phone.text = (userRow.phone ?? '').trim();
      _adresse.text = (userRow.adresse ?? '').trim();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _initLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final profileId = _profile?.id;
    if (profileId == null || profileId.isEmpty) {
      setState(() {
        _error = 'Impossible de retrouver le profil utilisateur';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cleanedName = _name.text.trim();

      await _usersService.updateById(profileId, {
        'name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'adresse': _adresse.text.trim().isEmpty ? null : _adresse.text.trim(),
        'nom': cleanedName.isEmpty ? null : cleanedName,
      });
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour avec succès')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Mon Profil',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _initLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.padding,
                12,
                AppSizes.padding,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1ED9D2), Color(0xFF0FC2DA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1ED9D2).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.account_circle,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profile?.name?.trim().isNotEmpty == true
                                    ? _profile!.name!
                                    : (_profile?.nom?.trim().isNotEmpty == true
                                          ? _profile!.nom!
                                          : 'Utilisateur'),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _authEmail,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(AppSizes.padding),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingLg),
                    decoration: BoxDecoration(
                      color: AppColors.brandSurface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Informations personnelles',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.text,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Modifie tes informations de profil',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.mutedText),
                        ),
                        const SizedBox(height: 20),
                        AppTextField(
                          controller: _name,
                          label: 'Nom',
                          hint: 'Ton nom',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _phone,
                          label: 'Numéro',
                          hint: 'Ex: +221 77 123 45 67',
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _adresse,
                          label: 'Adresse de livraison',
                          hint: 'Adresse complète',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                        ),
                        const SizedBox(height: 20),
                        AppButton(
                          label: 'Enregistrer les modifications',
                          loading: _loading,
                          onPressed: _loading ? null : _save,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
