import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final client = Supabase.instance.client;

    final ordersRows = await client.from('orders').select('id, status, total_price');
    final orders = (ordersRows as List).cast<Map<String, dynamic>>();

    final totalOrders = orders.length;
    final pendingOrders = orders.where((o) => o['status'] == 'pending').length;
    final processingOrders = orders.where((o) => o['status'] == 'processing').length;
    final shippedOrders = orders.where((o) => o['status'] == 'shipped').length;
    final deliveredOrders = orders.where((o) => o['status'] == 'delivered').length;
    final cancelledOrders = orders.where((o) => o['status'] == 'cancelled').length;

    double revenue = 0;
    for (final o in orders) {
      if (o['status'] != 'cancelled') {
        final tp = o['total_price'];
        if (tp != null) revenue += (tp as num).toDouble();
      }
    }

    final clientsRows = await client
        .from('users')
        .select('id, role_id, roles(name)')
        .order('id');
    final clients = (clientsRows as List).cast<Map<String, dynamic>>();
    final totalClients = clients.where((u) {
      final r = u['roles'];
      if (r is Map) {
        final name = (r['name'] as String?)?.toLowerCase().trim();
        return name == 'client';
      }
      return false;
    }).length;

    // Top products
    final itemsRows = await client
        .from('order_items')
        .select('product_id, quantity');
    final items = (itemsRows as List).cast<Map<String, dynamic>>();
    final productQty = <int, int>{};
    for (final item in items) {
      final pid = item['product_id'] as int?;
      final qty = item['quantity'] as int? ?? 0;
      if (pid != null) {
        productQty[pid] = (productQty[pid] ?? 0) + qty;
      }
    }

    final sortedProducts = productQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedProducts.take(5).toList();

    // Fetch product names
    final topProductNames = <int, String>{};
    if (top5.isNotEmpty) {
      final ids = top5.map((e) => e.key).toList();
      final prodRows = await client
          .from('products')
          .select('id, name')
          .inFilter('id', ids);
      for (final row in (prodRows as List).cast<Map<String, dynamic>>()) {
        topProductNames[row['id'] as int] = row['name'] as String;
      }
    }

    final topProducts = top5
        .map((e) => _TopProduct(
              name: topProductNames[e.key] ?? 'Produit #${e.key}',
              quantity: e.value,
            ))
        .toList();

    return _DashboardData(
      totalOrders: totalOrders,
      pendingOrders: pendingOrders,
      processingOrders: processingOrders,
      shippedOrders: shippedOrders,
      deliveredOrders: deliveredOrders,
      cancelledOrders: cancelledOrders,
      revenue: revenue,
      totalClients: totalClients,
      topProducts: topProducts,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Tableau de bord',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            color: AppColors.mutedText,
          ),
        ],
      ),
      body: FutureBuilder<_DashboardData>(
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

          final data = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.padding, 10, AppSizes.padding, 40,
            ),
            children: [
              _buildStatRow(context, [
                _StatCard(
                  title: 'Total commandes',
                  value: '${data.totalOrders}',
                  icon: Icons.shopping_bag_outlined,
                  color: AppColors.accent,
                ),
                _StatCard(
                  title: 'Clients',
                  value: '${data.totalClients}',
                  icon: Icons.people_outline,
                  color: Colors.blue,
                ),
              ]),
              const SizedBox(height: 12),
              _buildStatRow(context, [
                _StatCard(
                  title: 'En attente',
                  value: '${data.pendingOrders}',
                  icon: Icons.hourglass_empty,
                  color: AppColors.mutedText,
                ),
                _StatCard(
                  title: 'En cours',
                  value: '${data.processingOrders}',
                  icon: Icons.autorenew,
                  color: Colors.orange,
                ),
              ]),
              const SizedBox(height: 12),
              _buildStatRow(context, [
                _StatCard(
                  title: 'Expédiées',
                  value: '${data.shippedOrders}',
                  icon: Icons.local_shipping_outlined,
                  color: Colors.blue,
                ),
                _StatCard(
                  title: 'Livrées',
                  value: '${data.deliveredOrders}',
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                ),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingLg),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chiffre d\'affaires',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.black.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${data.revenue.toStringAsFixed(0)} F',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Produits les plus vendus',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (data.topProducts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingLg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Aucune vente enregistrée.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                )
              else
                ...data.topProducts.asMap().entries.map(
                  (entry) {
                    final i = entry.key;
                    final p = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusLg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.accent
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            '${p.quantity} vendus',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, List<_StatCard> cards) {
    return Row(
      children: cards
          .map((c) => Expanded(child: c))
          .expand((w) => [w, const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DashboardData {
  final int totalOrders;
  final int pendingOrders;
  final int processingOrders;
  final int shippedOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final double revenue;
  final int totalClients;
  final List<_TopProduct> topProducts;

  const _DashboardData({
    required this.totalOrders,
    required this.pendingOrders,
    required this.processingOrders,
    required this.shippedOrders,
    required this.deliveredOrders,
    required this.cancelledOrders,
    required this.revenue,
    required this.totalClients,
    required this.topProducts,
  });
}

class _TopProduct {
  final String name;
  final int quantity;

  const _TopProduct({required this.name, required this.quantity});
}
