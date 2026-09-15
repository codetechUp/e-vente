import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../models/app_user_model.dart';
import '../providers/auth_provider.dart';
import '../services/app_users_service.dart';
import '../services/location_service.dart';
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

  double? _profileLatitude;
  double? _profileLongitude;
  bool _gpsLoading = false;


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
      final authUser = Supabase.instance.client.auth.currentUser;
      final id = authUser?.id ?? '';
      if (id.isEmpty) {
        throw StateError('Utilisateur non connecté');
      }

      // Chercher d'abord par l'ID auth, puis par email
      AppUserModel? userRow = await _usersService.resolveForAuthUser(
        authUserId: id,
        email: _authEmail,
      );

      // Fallback : chercher par numéro de téléphone (connexion OTP - compte pré-inscrit)
      if (userRow == null) {
        final rawPhone = authUser?.phone ?? '';
        if (rawPhone.isNotEmpty) {
          userRow = await _usersService.getByPhone(rawPhone);
          
          // Si on trouve le compte pré-inscrit, on le lie à l'ID auth actuel
          if (userRow != null && userRow.id != id) {
            if (kDebugMode) {
              debugPrint('[ProfileView] Linking pre-registered user ${userRow.id} → auth $id');
            }
            try {
              // Supprimer le doublon créé par le trigger si existant
              final dup = await _usersService.getById(id);
              if (dup != null) await _usersService.deleteById(id);
              // Mettre à jour l'ID du compte pré-inscrit vers le nouvel ID auth
              await _usersService.updateById(userRow.id!, {'id': id});
              userRow = await _usersService.getById(id);
            } catch (e) {
              if (kDebugMode) debugPrint('[ProfileView] Link error: $e');
            }
          }
        }
      }

      if (userRow == null) {
        throw StateError('Profil introuvable dans la table users');
      }

      _profile = userRow;
      _name.text = (userRow.name ?? userRow.nom ?? '').trim();
      _phone.text = (userRow.phone ?? '').trim();
      _adresse.text = (userRow.adresse ?? '').trim();
      _profileLatitude = userRow.latitude;
      _profileLongitude = userRow.longitude;
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
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isClient = auth.isClient;

      await _usersService.updateById(profileId, {
        'name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        if (!isClient) 'adresse': _adresse.text.trim().isEmpty ? null : _adresse.text.trim(),
        'nom': cleanedName.isEmpty ? null : cleanedName,
        if (!isClient) 'latitude': _profileLatitude,
        if (!isClient) 'longitude': _profileLongitude,
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
    final auth = Provider.of<AuthProvider>(context);
    final isClient = auth.isClient;
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
                          enabled: !isClient,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Position GPS',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (_profileLatitude != null && _profileLongitude != null)
                                        ? '${_profileLatitude!.toStringAsFixed(6)}, ${_profileLongitude!.toStringAsFixed(6)}'
                                        : 'Aucune position GPS enregistrée',
                                    style: TextStyle(
                                      color: (_profileLatitude != null) ? AppColors.brandGreenDark : AppColors.mutedText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isClient) ...[
                              const SizedBox(width: 8),
                              _gpsLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.5),
                                    )
                                  : IconButton.filled(
                                      onPressed: _captureGPSLocation,
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppColors.brandGreen.withValues(alpha: 0.12),
                                        foregroundColor: AppColors.brandGreenDark,
                                      ),
                                      icon: const Icon(Icons.my_location),
                                      tooltip: 'Détecter ma position GPS',
                                    ),
                            ],
                          ],
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
                  if (_profile != null) ...[
                    const SizedBox(height: 20),
                    _buildQrCodeCard(context),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _captureGPSLocation() async {
    setState(() => _gpsLoading = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null) {
        setState(() {
          _profileLatitude = pos.latitude;
          _profileLongitude = pos.longitude;
        });
        
        final addr = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
        if (addr != null && addr.isNotEmpty) {
          setState(() {
            _adresse.text = addr;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d’obtenir votre position GPS. Veuillez vérifier vos permissions.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error in _captureGPSLocation: $e');
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Widget _buildQrCodeCard(BuildContext context) {
    if (_profile?.id == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            'Ma Carte Client QR',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Présentez ce QR Code pour vous identifier auprès d\'un commercial.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGreen.withValues(alpha: 0.15),
                    blurRadius: 20,
                  ),
                ],
                border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.3), width: 1.5),
              ),
              child: QrImageView(
                data: _profile!.id!,
                version: QrVersions.auto,
                size: 180.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.brandGreenDark,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.brandGreenDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'ID: ${_profile!.id}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.mutedText,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
