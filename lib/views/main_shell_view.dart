import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_model.dart';
import '../services/app_users_service.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../services/realtime_notification_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/styled_bottom_nav.dart';
import '../widgets/web_sidebar.dart';
import 'admin_shell_view.dart';
import 'delivery_person_shell_view.dart';
import 'preparateur_shell_view.dart';
import 'profile_view.dart';
import 'tabs/catalog_tab.dart';
import 'tabs/deliveries_tab.dart';
import 'tabs/discover_tab.dart';
import 'tabs/management_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/role_dashboard_tab.dart';
import 'commercial_shell_view.dart';

class MainShellView extends StatefulWidget {
  const MainShellView({super.key});

  @override
  State<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends State<MainShellView> {
  int _index = 0;
  RealtimeNotificationService? _realtimeService;

  @override
  void initState() {
    super.initState();
    // Démarrer l'écoute Realtime pour les notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      _realtimeService = RealtimeNotificationService();
      _realtimeService?.startListening(authProvider);
      _checkUserProfile();
    });
  }

  @override
  void dispose() {
    _realtimeService?.stopListening();
    super.dispose();
  }

  List<Widget> _buildTabs(UserRole? role) {
    switch (role) {
      case UserRole.admin:
        return [
          const RoleDashboardTab(role: UserRole.admin),
          DiscoverTab(onSwitchTab: (i) => setState(() => _index = i)),
          const CatalogTab(),
          const OrdersTab(),
          const ManagementTab(),
        ];
      case UserRole.livreur:
        return [
          const RoleDashboardTab(role: UserRole.livreur),
          DiscoverTab(onSwitchTab: (i) => setState(() => _index = i)),
          const CatalogTab(),
          const DeliveriesTab(),
        ];
      case UserRole.client:
      default:
        return [
          DiscoverTab(onSwitchTab: (i) => setState(() => _index = i)),
          const CatalogTab(),
          const OrdersTab(),
        ];
    }
  }

  List<BottomNavigationBarItem> _buildNavItems(
    UserRole? role,
    BuildContext context,
  ) {
    switch (role) {
      case UserRole.admin:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Découvrir',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Catalogue',
          ),
          BottomNavigationBarItem(
            icon: _buildOrdersIcon(context),
            activeIcon: _buildOrdersIcon(context),
            label: 'Commandes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Gestion',
          ),
        ];
      case UserRole.livreur:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Découvrir',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Catalogue',
          ),
          BottomNavigationBarItem(
            icon: _buildOrdersIcon(context),
            activeIcon: _buildOrdersIcon(context),
            label: 'Livraisons',
          ),
        ];
      case UserRole.client:
      default:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Découvrir',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Catalogue',
          ),
          BottomNavigationBarItem(
            icon: _buildOrdersIcon(context),
            activeIcon: _buildOrdersIcon(context),
            label: 'Commandes',
          ),
        ];
    }
  }

  String _roleDisplayName(UserRole? role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrateur';
      case UserRole.livreur:
        return 'Livreur';
      case UserRole.client:
        return 'Client';
      default:
        return 'Client';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = Supabase.instance.client.auth.currentUser;
    final role = auth.role;

    if (role == UserRole.admin) {
      return const AdminShellView();
    }

    if (role == UserRole.livreur) {
      return const DeliveryPersonShellView();
    }

    if (role == UserRole.preparateur) {
      return const PreparateurShellView();
    }

    if (role == UserRole.commercial) {
      return const CommercialShellView();
    }

    final tabs = _buildTabs(role);
    final navItems = _buildNavItems(role, context);

    if (kDebugMode) {
      final navLabels = navItems.map((item) => item.label).join(', ');
      debugPrint(
        '[MainShellView] user uid=${user?.id} email=${user?.email} roleEnum=$role roleName=${auth.roleName} isAdmin=${auth.isAdmin} isClient=${auth.isClient} isLivreur=${auth.isLivreur}',
      );
      debugPrint(
        '[MainShellView] tabsCount=${tabs.length} navItems=[$navLabels] currentIndex=$_index',
      );
    }

    if (_index >= tabs.length) {
      _index = 0;
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;

    if (isDesktop) {
      final sidebarItems = _buildSidebarItems(role, context);
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            WebSidebar(
              currentIndex: _index,
              items: sidebarItems,
              onTap: (i) => setState(() => _index = i),
              onLogout: () => auth.logout(),
              userName: user?.userMetadata?['name'] as String? ?? 'Utilisateur',
              userEmail: user?.email ?? '',
              roleName: _roleDisplayName(role),
              avatarLetter: user?.avatarLetter ?? '?',
            ),
            Expanded(
              child: IndexedStack(index: _index, children: tabs),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.paddingLg),
                decoration: const BoxDecoration(color: AppColors.background),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 70,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.storefront,
                          size: 48,
                          color: AppColors.brandGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 12),
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                      child: Text(
                        user?.avatarLetter ?? '?',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.userMetadata?['name'] as String? ?? 'Utilisateur',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _roleDisplayName(role),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Mon Profil'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileView()),
                  );
                },
              ),
              const Spacer(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: Text(
                  'Se déconnecter',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await context.read<AuthProvider>().logout();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: StyledBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: navItems,
      ),
    );
  }

  List<SidebarItem> _buildSidebarItems(UserRole? role, BuildContext context) {
    final navItems = _buildNavItems(role, context);
    return navItems.map((item) {
      IconData icon = Icons.circle;
      IconData activeIcon = Icons.circle;
      if (item.icon is Icon) {
        icon = (item.icon as Icon).icon ?? Icons.circle;
      }
      if (item.activeIcon is Icon) {
        activeIcon = (item.activeIcon as Icon).icon ?? Icons.circle;
      }
      
      Widget? badgeWidget;
      if (item.icon is Badge) {
        final b = item.icon as Badge;
        badgeWidget = b.label;
        if (b.child is Icon) {
          icon = (b.child as Icon).icon ?? Icons.circle;
        }
      }
      if (item.activeIcon is Badge) {
        final ab = item.activeIcon as Badge;
        if (ab.child is Icon) {
          activeIcon = (ab.child as Icon).icon ?? Icons.circle;
        }
      }
      
      return SidebarItem(
        icon: icon,
        activeIcon: activeIcon,
        label: item.label ?? '',
        badge: badgeWidget != null ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            child: badgeWidget,
          ),
        ) : null,
      );
    }).toList();
  }

  Widget _buildOrdersIcon(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final pendingCount = context
        .watch<OrdersProvider>()
        .getPendingOrdersCountForClient(userId);

    return Badge(
      label: Text(
        pendingCount.toString(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
      ),
      isLabelVisible: pendingCount > 0,
      backgroundColor: AppColors.danger,
      child: const Icon(Icons.local_shipping_outlined),
    );
  }

  Future<void> _checkUserProfile() async {
    final authProvider = context.read<AuthProvider>();
    // Attendre un peu que le rôle soit correctement résolu ou chargé
    if (authProvider.role != UserRole.client) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final userRow = await AppUsersService().getById(currentUser.id);
      if (userRow != null) {
        final hasName = userRow.name?.trim().isNotEmpty == true || userRow.nom?.trim().isNotEmpty == true;
        final hasAddress = userRow.adresse?.trim().isNotEmpty == true;
        final hasPhone = userRow.phone?.trim().isNotEmpty == true;
        final hasRealEmail = userRow.email.trim().isNotEmpty == true && userRow.email.contains('@');

        if (!hasName || !hasAddress || !hasPhone || !hasRealEmail) {
          if (mounted) {
            _showCompleteProfileDialog(userRow);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MainShellView] Error checking user profile: $e');
      }
    }
  }

  void _showCompleteProfileDialog(AppUserModel userRow) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: userRow.name ?? userRow.nom ?? '');
    final phoneCtrl = TextEditingController(text: userRow.phone ?? '');
    final emailCtrl = TextEditingController(
      text: userRow.email.contains('@') ? userRow.email : '',
    );
    final addressCtrl = TextEditingController(text: userRow.adresse ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    const Icon(Icons.lock_person_outlined, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Complétez votre profil',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Pour continuer, veuillez renseigner vos informations de profil obligatoires.',
                          style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nom complet *',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Nom obligatoire' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Numéro de téléphone *',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Téléphone obligatoire';
                            }
                            if (v.trim().length < 8) {
                              return 'Numéro invalide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Adresse Email *',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email obligatoire';
                            }
                            if (!v.contains('@') || !v.contains('.')) {
                              return 'Email invalide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressCtrl,
                          decoration: InputDecoration(
                            labelText: 'Adresse de livraison *',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Adresse obligatoire' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (formKey.currentState?.validate() ?? false) {
                              setState(() => isSaving = true);
                              try {
                                final usersService = AppUsersService();
                                await usersService.updateById(userRow.id!, {
                                  'name': nameCtrl.text.trim(),
                                  'nom': nameCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                  'email': emailCtrl.text.trim(),
                                  'adresse': addressCtrl.text.trim(),
                                });
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profil complété avec succès !'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setState(() => isSaving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur lors de la sauvegarde : $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Enregistrer et Continuer'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
