import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/styled_bottom_nav.dart';
import '../widgets/web_sidebar.dart';
import 'tabs/management_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/role_dashboard_tab.dart';

class AdminShellView extends StatefulWidget {
  const AdminShellView({super.key});

  @override
  State<AdminShellView> createState() => _AdminShellViewState();
}

class _AdminShellViewState extends State<AdminShellView> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    RoleDashboardTab(role: UserRole.admin),
    OrdersTab(),
    ManagementTab(),
  ];

  List<SidebarItem> _buildSidebarItems(BuildContext context) {
    final pendingCount = context.watch<OrdersProvider>().pendingOrdersCount;
    return [
      const SidebarItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard',
      ),
      SidebarItem(
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping,
        label: 'Commandes',
        badge: pendingCount > 0 ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            pendingCount.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ) : null,
      ),
      const SidebarItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Gestion',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = Supabase.instance.client.auth.currentUser;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    if (isDesktop) {
      final sidebarItems = _buildSidebarItems(context);
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            WebSidebar(
              currentIndex: _currentIndex,
              items: sidebarItems,
              onTap: (i) => setState(() => _currentIndex = i),
              onLogout: () => auth.logout(),
              userName: user?.userMetadata?['name'] as String? ?? 'Administrateur',
              userEmail: user?.email ?? '',
              roleName: auth.roleName ?? 'Administrateur',
              avatarLetter: user?.avatarLetter ?? '?',
            ),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _pages),
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
                      user?.userMetadata?['name'] as String? ??
                          'Administrateur',
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
                        auth.roleName ?? 'Administrateur',
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
                  await auth.logout();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: StyledBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: _buildOrdersIcon(context, false),
            activeIcon: _buildOrdersIcon(context, true),
            label: 'Commandes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Gestion',
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersIcon(BuildContext context, bool isActive) {
    final pendingCount = context.watch<OrdersProvider>().pendingOrdersCount;

    return Badge(
      label: Text(
        pendingCount.toString(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
      ),
      isLabelVisible: pendingCount > 0,
      backgroundColor: AppColors.danger,
      child: Icon(
        isActive ? Icons.local_shipping : Icons.local_shipping_outlined,
      ),
    );
  }
}
