import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../services/app_users_service.dart';
import '../../services/deliveries_service.dart';
import '../../utils/constants/app_colors.dart';
import '../../utils/constants/app_sizes.dart';
import '../dashboard_view.dart';

class RoleDashboardTab extends StatelessWidget {
  final UserRole role;

  const RoleDashboardTab({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case UserRole.admin:
        return const DashboardView();
      case UserRole.livreur:
        return const _LivreurDashboardView();
      case UserRole.client:
        return const SizedBox.shrink();
    }
  }
}

class _LivreurDashboardView extends StatefulWidget {
  const _LivreurDashboardView();

  @override
  State<_LivreurDashboardView> createState() => _LivreurDashboardViewState();
}

class _LivreurDashboardViewState extends State<_LivreurDashboardView> {
  final _usersService = AppUsersService();
  final _deliveriesService = DeliveriesService();

  late Future<_LivreurDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LivreurDashboardData> _load() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) {
      return const _LivreurDashboardData();
    }

    final appUser = await _usersService.resolveForAuthUser(
      authUserId: authUser.id,
      email: authUser.email,
    );
    if (appUser?.id == null) {
      return const _LivreurDashboardData();
    }

    final deliveries = await _deliveriesService.getAll();
    final mine = deliveries
        .where((d) => d.deliveryPersonId == appUser!.id)
        .toList();

    final pending = mine.where((d) => d.status == 'pending').length;
    final processing = mine.where((d) => d.status == 'processing').length;
    final shipped = mine.where((d) => d.status == 'shipped').length;
    final delivered = mine.where((d) => d.status == 'delivered').length;

    return _LivreurDashboardData(
      totalDeliveries: mine.length,
      pendingDeliveries: pending,
      processingDeliveries: processing,
      shippedDeliveries: shipped,
      deliveredDeliveries: delivered,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LivreurDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.padding),
              child: Text('Erreur: ${snapshot.error}'),
            ),
          );
        }

        final data = snapshot.data ?? const _LivreurDashboardData();

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(
                'Dashboard livreur',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              backgroundColor: AppColors.background,
              elevation: 0,
              floating: true,
              pinned: false,
              actions: [
                IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  color: AppColors.mutedText,
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.padding,
                10,
                AppSizes.padding,
                40,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingLg),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1ED9D2), Color(0xFF0FC2DA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tes tournées du jour',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Suis rapidement tes livraisons assignées et celles déjà terminées.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow([
                    _MiniStatCard(
                      title: 'Total',
                      value: '${data.totalDeliveries}',
                      icon: Icons.local_shipping_outlined,
                      color: AppColors.accent,
                    ),
                    _MiniStatCard(
                      title: 'En attente',
                      value: '${data.pendingDeliveries}',
                      icon: Icons.hourglass_empty,
                      color: AppColors.mutedText,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _buildStatRow([
                    _MiniStatCard(
                      title: 'En cours',
                      value: '${data.processingDeliveries}',
                      icon: Icons.autorenew,
                      color: Colors.orange,
                    ),
                    _MiniStatCard(
                      title: 'Expédiées',
                      value: '${data.shippedDeliveries}',
                      icon: Icons.send_outlined,
                      color: Colors.blue,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _MiniStatCard(
                    title: 'Livrées',
                    value: '${data.deliveredDeliveries}',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    fullWidth: true,
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(List<Widget> cards) {
    return Row(
      children:
          cards
              .map((card) => Expanded(child: card))
              .expand((card) => [card, const SizedBox(width: 12)])
              .toList()
            ..removeLast(),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool fullWidth;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivreurDashboardData {
  final int totalDeliveries;
  final int pendingDeliveries;
  final int processingDeliveries;
  final int shippedDeliveries;
  final int deliveredDeliveries;

  const _LivreurDashboardData({
    this.totalDeliveries = 0,
    this.pendingDeliveries = 0,
    this.processingDeliveries = 0,
    this.shippedDeliveries = 0,
    this.deliveredDeliveries = 0,
  });
}
