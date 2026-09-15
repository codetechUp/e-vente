import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_model.dart';
import '../providers/auth_provider.dart';
import '../services/app_users_service.dart';
import '../services/location_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/app_button.dart';

class ClientQrScannerDialog {
  static Future<void> show(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _ScannerDialogContent(),
    );

    if (result != null && result.isNotEmpty) {
      if (!context.mounted) return;
      showClientDetails(context, result);
    }
  }

  static Future<void> showClientDetails(BuildContext context, String clientId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final usersService = AppUsersService();
      final client = await usersService.getById(clientId);
      
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading indicator

      if (client == null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Erreur', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Aucun client correspondant à cet identifiant n\'a été trouvé.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Fetch creator/referrer details if exists
      AppUserModel? referrer;
      if (client.referrerId != null && client.referrerId!.isNotEmpty) {
        try {
          referrer = await usersService.getById(client.referrerId!);
        } catch (_) {
          // Ignore
        }
      }

      if (!context.mounted) return;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ClientDetailsSheet(client: client, referrer: referrer),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement : $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}

class _ScannerDialogContent extends StatefulWidget {
  const _ScannerDialogContent();

  @override
  State<_ScannerDialogContent> createState() => _ScannerDialogContentState();
}

class _ScannerDialogContentState extends State<_ScannerDialogContent> {
  final TextEditingController _ctrl = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _cameraError = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _scanFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // Montrer un indicateur de chargement
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final BarcodeCapture? capture = await _scannerController.analyzeImage(image.path);
      
      if (!mounted) return;
      Navigator.pop(context); // Fermer l'indicateur de chargement

      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? qrCode = capture.barcodes.first.rawValue;
        if (qrCode != null && qrCode.isNotEmpty) {
          if (mounted) {
            Navigator.pop(context, qrCode);
          }
        } else {
          _showNoQrError();
        }
      } else {
        _showNoQrError();
      }
    } catch (e) {
      if (mounted) {
        // Tenter de fermer le dialogue de chargement au cas où
        try {
          Navigator.pop(context);
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du scan de l\'image : $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showNoQrError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aucun code QR lisible n\'a été trouvé dans cette image.'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(LucideIcons.qrCode, color: AppColors.brandGreenDark),
          SizedBox(width: 10),
          Text(
            'Scanner un Client',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Scannez le QR Code de votre client ou collez/saisissez son identifiant UUID unique ci-dessous.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: _cameraError
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.cameraOff, size: 44, color: AppColors.danger),
                        SizedBox(height: 10),
                        Text(
                          'Erreur Caméra / Permission',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Veuillez utiliser la saisie manuelle ci-dessous.',
                          style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              if (barcode.rawValue != null) {
                                Navigator.pop(context, barcode.rawValue);
                                break;
                              }
                            }
                          },
                          errorBuilder: (context, error) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_cameraError) {
                                setState(() {
                                  _cameraError = true;
                                });
                              }
                            });
                            return const Center(
                              child: Icon(LucideIcons.cameraOff, size: 44, color: AppColors.danger),
                            );
                          },
                        ),
                        // Scanner overlay frame
                        Center(
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.brandGreen, width: 2.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _scanFromGallery,
              icon: const Icon(LucideIcons.image, size: 18, color: AppColors.brandGreenDark),
              label: const Text('Choisir une photo (Galerie)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandGreenDark)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppColors.brandGreen, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Coller l\'identifiant (UUID)',
                hintText: 'xxxx-xxxx-xxxx-xxxx',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppColors.mutedText, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _ClientDetailsSheet extends StatefulWidget {
  final AppUserModel client;
  final AppUserModel? referrer;

  const _ClientDetailsSheet({
    required this.client,
    required this.referrer,
  });

  @override
  State<_ClientDetailsSheet> createState() => _ClientDetailsSheetState();
}

class _ClientDetailsSheetState extends State<_ClientDetailsSheet> {
  late AppUserModel _client;
  bool _gpsUpdating = false;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
  }

  Future<void> _editClientProfile() async {
    final nameCtrl = TextEditingController(text: _client.name ?? _client.nom ?? '');
    final phoneCtrl = TextEditingController(
      text: (_client.phone ?? '').startsWith('+221')
          ? (_client.phone ?? '').substring(4)
          : (_client.phone ?? ''),
    );
    final addressCtrl = TextEditingController(text: _client.adresse ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(LucideIcons.edit3, color: AppColors.brandGreenDark),
              SizedBox(width: 10),
              Text('Modifier le profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nom Complet',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Téléphone (sans +221)',
                      prefixText: '+221 ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requis';
                      if (v.trim().length < 9) return 'Trop court (ex: 771234567)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Adresse de livraison',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: AppColors.mutedText)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final rawPhone = phoneCtrl.text.trim().replaceAll(' ', '');
                        final phone = '+221$rawPhone';

                        await AppUsersService().updateById(_client.id!, {
                          'name': nameCtrl.text.trim(),
                          'nom': nameCtrl.text.trim(),
                          'phone': phone,
                          'adresse': addressCtrl.text.trim(),
                        });

                        final updated = await AppUsersService().getById(_client.id!);
                        if (updated != null) {
                          setState(() {
                            _client = updated;
                          });
                        }
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profil mis à jour avec succès !'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
                          );
                        }
                      } finally {
                        setDialogState(() => saving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateGPSLocation() async {
    setState(() => _gpsUpdating = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null) {
        // reverse geocode to get new address name
        final newAddress = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
        
        await AppUsersService().updateById(_client.id!, {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          if (newAddress != null && newAddress.isNotEmpty) 'adresse': newAddress,
        });

        // Refresh state
        final updatedClient = await AppUsersService().getById(_client.id!);
        if (updatedClient != null) {
          setState(() {
            _client = updatedClient;
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Localisation GPS et adresse mises à jour avec succès !'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de détecter le GPS.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _gpsUpdating = false);
    }
  }

  Future<void> _openGoogleMaps() async {
    if (_client.latitude == null || _client.longitude == null) return;
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${_client.latitude},${_client.longitude}',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'ouvrir l\'application Google Maps')),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Google Maps Launch Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = (_client.name != null && _client.name!.trim().isNotEmpty)
        ? _client.name!
        : (_client.nom ?? 'Sans nom');
        
    final creatorName = widget.referrer != null
        ? '${widget.referrer!.name ?? widget.referrer!.nom ?? "Commercial"} (${widget.referrer!.phone ?? "Pas de numéro"})'
        : 'Administrateur (Direct)';

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isAllowedToEdit = auth.isAdmin || (_client.referrerId != null && _client.referrerId == currentUserId);

    return Container(
      padding: EdgeInsets.only(
        left: AppSizes.paddingLg,
        right: AppSizes.paddingLg,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          
          // Header info
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.user, color: AppColors.brandGreenDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.text),
                    ),
                    Text(
                      _client.phone ?? 'Aucun téléphone',
                      style: const TextStyle(color: AppColors.mutedText, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (isAllowedToEdit)
                IconButton(
                  icon: const Icon(LucideIcons.edit3, color: AppColors.brandGreenDark),
                  onPressed: _editClientProfile,
                  tooltip: 'Modifier les informations',
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Profile Details Grid/Cards
          _buildInfoRow(LucideIcons.mail, 'E-mail', _client.email),
          _buildInfoRow(LucideIcons.mapPin, 'Adresse de livraison', _client.adresse ?? 'Aucune adresse'),
          _buildInfoRow(LucideIcons.userPlus, 'Ajouté par', creatorName),
          
          // GPS Coords row
          _buildInfoRow(
            LucideIcons.globe,
            'Coordonnées GPS',
            (_client.latitude != null && _client.longitude != null)
                ? '${_client.latitude!.toStringAsFixed(6)}, ${_client.longitude!.toStringAsFixed(6)}'
                : 'Aucune position GPS enregistrée',
            suffix: (_client.latitude != null && _client.longitude != null)
                ? TextButton.icon(
                    onPressed: _openGoogleMaps,
                    icon: const Icon(LucideIcons.navigation, size: 14, color: AppColors.brandGreenDark),
                    label: const Text('Maps', style: TextStyle(color: AppColors.brandGreenDark, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          
          // Actions Buttons
          Row(
            children: [
              if (isAllowedToEdit) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _gpsUpdating ? null : _updateGPSLocation,
                    icon: _gpsUpdating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.mapPin, size: 18),
                    label: const Text('Actualiser GPS', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: AppButton(
                  label: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.mutedText)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.text),
                ),
              ],
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }
}
