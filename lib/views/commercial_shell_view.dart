import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../providers/auth_provider.dart';
import '../utils/constants/app_colors.dart';
import '../widgets/modern_card.dart';
import '../widgets/web_sidebar.dart';
import '../widgets/styled_bottom_nav.dart';
import '../models/app_user_model.dart';
import '../services/app_users_service.dart';
import '../services/location_service.dart';
import '../widgets/client_qr_scanner_dialog.dart';
import 'package:flutter/foundation.dart';

class CommercialShellView extends StatefulWidget {
  const CommercialShellView({super.key});

  @override
  State<CommercialShellView> createState() => _CommercialShellViewState();
}

class _CommercialShellViewState extends State<CommercialShellView> {
  int _currentIndex = 0;
  bool _loading = false;
  List<AppUserModel> _myClients = [];
  Map<String, dynamic> _stats = {
    'totalClients': 0,
    'totalOrders': 0,
    'totalSales': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch referred clients
      final clientRows = await Supabase.instance.client
          .from('users')
          .select()
          .eq('referrer_id', user.id);

      final clients = (clientRows as List)
          .cast<Map<String, dynamic>>()
          .map((e) => AppUserModel.fromJson(e))
          .toList();

      // 2. Fetch orders from these clients
      int ordersCount = 0;
      double salesSum = 0.0;

      if (clients.isNotEmpty) {
        final clientIds = clients.map((c) => c.id).whereType<String>().toList();
        if (clientIds.isNotEmpty) {
          final orderRows = await Supabase.instance.client
              .from('orders')
              .select('total_price')
              .inFilter('user_id', clientIds);

          ordersCount = orderRows.length;
          for (final o in orderRows) {
            final price = o['total_price'];
            if (price != null) {
              salesSum += (price as num).toDouble();
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _myClients = clients;
          _stats = {
            'totalClients': clients.length,
            'totalOrders': ordersCount,
            'totalSales': salesSum,
          };
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement données: $e')),
        );
      }
    }
  }

  List<SidebarItem> _buildSidebarItems() {
    return [
      const SidebarItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Tableau de bord',
      ),
      const SidebarItem(
        icon: Icons.person_add_outlined,
        activeIcon: Icons.person_add,
        label: 'Ajouter un client',
      ),
      const SidebarItem(
        icon: Icons.qr_code_2_outlined,
        activeIcon: Icons.qr_code_2,
        label: 'Mon QR Code',
      ),
    ];
  }

  List<BottomNavigationBarItem> _buildNavItems() {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_add_outlined),
        activeIcon: Icon(Icons.person_add),
        label: 'Ajout Client',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.qr_code_scanner_outlined),
        activeIcon: Icon(Icons.qr_code),
        label: 'Mon QR',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = Supabase.instance.client.auth.currentUser;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    final tabs = [
      _buildDashboardTab(user?.id ?? ''),
      _buildAddClientTab(user?.id ?? ''),
      _buildQrCodeTab(user?.id ?? ''),
    ];

    if (isDesktop) {
      final sidebarItems = _buildSidebarItems();
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            WebSidebar(
              currentIndex: _currentIndex,
              items: sidebarItems,
              onTap: (i) => setState(() => _currentIndex = i),
              onLogout: () => auth.logout(),
              userName: user?.userMetadata?['name'] as String? ?? 'Commercial',
              userEmail: user?.email ?? '',
              roleName: 'Commercial',
              avatarLetter: user?.avatarLetter ?? '?',
            ),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: tabs),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Espace Commercial',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => ClientQrScannerDialog.show(context),
            tooltip: 'Scanner un client',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.danger),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: StyledBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: _buildNavItems(),
      ),
    );
  }

  // --- SUB TABS ---

  Widget _buildDashboardTab(String commercialId) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Welcome Widget
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brandGreen, AppColors.brandGreenDark],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mon Tableau de Bord',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Suivez vos filleuls, générez des QR Codes et enregistrez de nouveaux clients.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Scanner Button Widget
              GestureDetector(
                onTap: () => ClientQrScannerDialog.show(context),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.brandGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scanner un Client (QR)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.brandGreenDark),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Scannez le code QR pour voir ses infos et mettre à jour sa localisation GPS.',
                                style: TextStyle(fontSize: 11, color: AppColors.mutedText),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.brandGreenDark),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Clients',
                      _stats['totalClients'].toString(),
                      Icons.people_alt_outlined,
                      const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Commandes',
                      _stats['totalOrders'].toString(),
                      Icons.shopping_bag_outlined,
                      const Color(0xFFEC4899),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Volume de vente généré',
                '${(_stats['totalSales'] as double).toStringAsFixed(0)} F CFA',
                Icons.monetization_on_outlined,
                const Color(0xFF10B981),
              ),
              const SizedBox(height: 32),
              // Referred Clients List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mes Clients Parrainés',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
                  ),
                  Text(
                    '${_myClients.length} au total',
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedText, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_myClients.isEmpty)
                ModernCard(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucun client parrainé pour le moment.',
                          style: TextStyle(color: AppColors.mutedText, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._myClients.map((client) {
                  final regDate = client.createdAt != null
                      ? DateFormat('dd MMM yyyy').format(client.createdAt!)
                      : 'Date inconnue';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: () => ClientQrScannerDialog.showClientDetails(context, client.id!),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ModernCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.brandGreen.withOpacity(0.15),
                                child: Text(
                                  client.avatarLetter,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandGreenDark),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      client.nom ?? client.name ?? 'Client',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tél: ${client.phone ?? "Non renseigné"}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Inscrit le',
                                        style: TextStyle(fontSize: 9, color: AppColors.mutedText),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        regDate,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.text),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
            ],
          );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedText, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ADD CLIENT FORM TAB ---

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _saving = false;
  double? _capturedLatitude;
  double? _capturedLongitude;
  bool _gpsLoading = false;

  Widget _buildAddClientTab(String commercialId) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ajouter un Nouveau Client',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enregistrez directement un client. Le compte sera créé et automatiquement associé à votre compte commercial.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ModernCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nom complet *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Nom complet obligatoire' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone (ex: 771234567) *',
                        prefixText: '+221 ',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Téléphone obligatoire';
                        final cleaned = v.trim().replaceAll(' ', '');
                        if (cleaned.length != 9 || !cleaned.startsWith('7')) {
                          return 'Le numéro doit contenir 9 chiffres et commencer par 7';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Adresse de livraison *',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Adresse obligatoire' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Position GPS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (_capturedLatitude != null && _capturedLongitude != null)
                                    ? '${_capturedLatitude!.toStringAsFixed(6)}, ${_capturedLongitude!.toStringAsFixed(6)}'
                                    : 'Aucune position GPS',
                                style: TextStyle(
                                  color: (_capturedLatitude != null) ? AppColors.brandGreenDark : AppColors.mutedText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                tooltip: 'Détecter la position GPS',
                              ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : () => _submitClientForm(commercialId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Enregistrer le client',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          _capturedLatitude = pos.latitude;
          _capturedLongitude = pos.longitude;
        });
        final addr = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
        if (addr != null && addr.isNotEmpty) {
          setState(() {
            _addressController.text = addr;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d’obtenir la position GPS.')),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GPS Error: $e');
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _submitClientForm(String commercialId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      final rawPhone = _phoneController.text.trim().replaceAll(' ', '');
      final phone = '+221$rawPhone';
      final address = _addressController.text.trim();

      // Find client role ID
      final roleRow = await Supabase.instance.client
          .from('roles')
          .select('id')
          .eq('name', 'client')
          .maybeSingle();

      final clientRoleId = roleRow != null ? roleRow['id'] as int? : null;

      // Insert pre-registration row in public.users
      final randomUuid = const Uuid().v4();
      
      final clientModel = AppUserModel(
        id: randomUuid,
        name: name,
        nom: name,
        email: '',
        phone: phone,
        adresse: address,
        roleId: clientRoleId,
        isActive: true,
        referrerId: commercialId,
        latitude: _capturedLatitude,
        longitude: _capturedLongitude,
      );

      await AppUsersService().create(clientModel);

      if (mounted) {
        _nameController.clear();
        _phoneController.clear();
        _addressController.clear();
        setState(() {
          _saving = false;
          _capturedLatitude = null;
          _capturedLongitude = null;
          _currentIndex = 0; // Return to dashboard
        });
        _loadData(); // Reload list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client enregistré et pré-inscrit avec succès !'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'enregistrement : $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // --- QR CODE DISPLAY TAB ---

  Widget _buildQrCodeTab(String commercialId) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Mon QR Code de Parrainage',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Présentez ce QR Code aux nouveaux clients lors de leur inscription dans l\'application pour lier leur compte à votre profil.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Center(
          child: ModernCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: commercialId,
                  version: QrVersions.auto,
                  size: 220.0,
                  foregroundColor: AppColors.text,
                ),
                const SizedBox(height: 16),
                const Text(
                  'SCANNEZ-MOI',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.brandGreenDark, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  commercialId,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline, color: AppColors.brandGreenDark),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Le client devra cliquer sur le bouton scanner de la caméra lors de son inscription pour scanner ce code.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
