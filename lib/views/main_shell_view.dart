import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/styled_bottom_nav.dart';
import 'admin_shell_view.dart';
import 'delivery_person_shell_view.dart';
import 'profile_view.dart';
import 'tabs/catalog_tab.dart';
import 'tabs/deliveries_tab.dart';
import 'tabs/discover_tab.dart';
import 'tabs/management_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/role_dashboard_tab.dart';

class MainShellView extends StatefulWidget {
  const MainShellView({super.key});

  @override
  State<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends State<MainShellView> {
  int _index = 0;

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
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                      child: Text(
                        (user?.email ?? '?')[0].toUpperCase(),
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
}
