import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';

enum DashboardDateFilter {
  all,
  today,
  last7days,
  last30days,
  custom,
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late Future<_DashboardData> _future;
  DashboardDateFilter _selectedDateFilter = DashboardDateFilter.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _dashboardTab = 'finances'; // finances, performance

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  bool _isWithinDateRange(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (_selectedDateFilter) {
      case DashboardDateFilter.today:
        return date.isAfter(todayStart);
      case DashboardDateFilter.last7days:
        final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
        return date.isAfter(sevenDaysAgo);
      case DashboardDateFilter.last30days:
        final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));
        return date.isAfter(thirtyDaysAgo);
      case DashboardDateFilter.custom:
        if (_customStartDate != null) {
          final isAfterStart = date.isAfter(_customStartDate!);
          final isBeforeEnd = _customEndDate == null || 
              date.isBefore(_customEndDate!.add(const Duration(days: 1)));
          return isAfterStart && isBeforeEnd;
        }
        return true;
      case DashboardDateFilter.all:
        return true;
    }
  }

  Future<_DashboardData> _load() async {
    final client = Supabase.instance.client;

    final ordersRows = await client
        .from('orders')
        .select('id, status, total_price, created_at');
    final allOrders = (ordersRows as List).cast<Map<String, dynamic>>();

    final orders = allOrders.where((o) {
      if (o['created_at'] == null) return false;
      final createdAt = DateTime.parse(o['created_at'] as String);
      return _isWithinDateRange(createdAt);
    }).toList();

    final totalOrders = orders.length;
    final pendingOrders = orders.where((o) => o['status'] == 'pending').length;
    final processingOrders = orders
        .where((o) => o['status'] == 'processing')
        .length;
    final shippedOrders = orders.where((o) => o['status'] == 'shipped').length;
    final deliveredOrders = orders
        .where((o) => o['status'] == 'delivered')
        .length;
    final cancelledOrders = orders
        .where((o) => o['status'] == 'cancelled')
        .length;

    double revenue = 0;
    for (final o in orders) {
      if (o['status'] == 'delivered') {
        final tp = o['total_price'];
        if (tp != null) revenue += (tp as num).toDouble();
      }
    }

    final clientsRows = await client
        .from('users')
        .select('id, role_id, roles(name), created_at')
        .order('id');
    final allClients = (clientsRows as List).cast<Map<String, dynamic>>();
    
    final totalClients = allClients.where((u) {
      final r = u['roles'];
      if (r is Map) {
        final name = (r['name'] as String?)?.toLowerCase().trim();
        if (name == 'client') {
          if (u['created_at'] == null) return false;
          final createdAt = DateTime.parse(u['created_at'] as String);
          return _isWithinDateRange(createdAt);
        }
      }
      return false;
    }).length;

    // Load order_items for finances and top selling products metrics
    final itemsRows = await client
        .from('order_items')
        .select('quantity, price, product_id, orders(created_at, status), products(name, purchase_price)');
    
    final allItems = (itemsRows as List).cast<Map<String, dynamic>>();

    double periodRevenue = 0.0;
    double periodCost = 0.0;
    final productSales = <int, _ProductPerformance>{};

    for (final row in allItems) {
      final order = row['orders'] as Map<String, dynamic>?;
      final product = row['products'] as Map<String, dynamic>?;
      if (order == null) continue;

      final status = order['status'] as String? ?? 'pending';
      if (status == 'cancelled') continue;

      final createdAtStr = order['created_at'] as String?;
      if (createdAtStr == null) continue;
      final createdAt = DateTime.parse(createdAtStr);

      if (!_isWithinDateRange(createdAt)) continue;

      final productId = (row['product_id'] as num?)?.toInt() ?? 0;
      final productName = product != null ? (product['name'] as String? ?? 'Produit inconnu') : 'Produit inconnu';
      final quantity = (row['quantity'] as num?)?.toInt() ?? 0;
      final price = (row['price'] as num?)?.toDouble() ?? 0.0;
      final purchasePrice = product != null && product['purchase_price'] != null
          ? (product['purchase_price'] as num).toDouble()
          : 0.0;

      periodRevenue += quantity * price;
      periodCost += quantity * purchasePrice;

      final perf = productSales.putIfAbsent(
        productId,
        () => _ProductPerformance(
          name: productName,
          quantity: 0,
          revenue: 0.0,
          profit: 0.0,
        ),
      );
      perf.quantity += quantity;
      perf.revenue += quantity * price;
      perf.profit += quantity * (price - purchasePrice);
    }

    double periodProfit = periodRevenue - periodCost;
    double periodMargin = periodRevenue > 0 ? (periodProfit / periodRevenue) * 100 : 0.0;

    final sortedPerformances = productSales.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    final topProducts = sortedPerformances.take(5).toList();

    // Stock valuation
    final productsRows = await client
        .from('products')
        .select('price, stock, purchase_price');
    final allProducts = (productsRows as List).cast<Map<String, dynamic>>();

    double stockValueVente = 0.0;
    double stockValueAchat = 0.0;
    for (final p in allProducts) {
      final price = (p['price'] as num?)?.toDouble() ?? 0.0;
      final stock = (p['stock'] as num?)?.toInt() ?? 0;
      final purchasePrice = (p['purchase_price'] as num?)?.toDouble() ?? 0.0;
      stockValueVente += price * stock;
      stockValueAchat += purchasePrice * stock;
    }
    double stockProfitPotential = stockValueVente - stockValueAchat;

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
      periodRevenue: periodRevenue,
      periodCost: periodCost,
      periodProfit: periodProfit,
      periodMargin: periodMargin,
      stockValueAchat: stockValueAchat,
      stockValueVente: stockValueVente,
      stockProfitPotential: stockProfitPotential,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  String _formatPrice(double price) {
    final parts = price.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(parts[i]);
    }
    return buffer.toString();
  }

  Widget _buildTabButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : AppColors.mutedText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isBold ? color : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValuationItem({
    required String label,
    required String value,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: color ?? AppColors.text,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Tableau de bord',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
          final deliveryRate = data.totalOrders > 0
              ? (data.deliveredOrders / data.totalOrders * 100)
              : 0.0;
          final cancelRate = data.totalOrders > 0
              ? (data.cancelledOrders / data.totalOrders * 100)
              : 0.0;
          final activeOrders = data.totalOrders - data.cancelledOrders;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.padding,
              10,
              AppSizes.padding,
              40,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.dashboard_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tableau de bord',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Vue d\'ensemble de votre activité',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Date Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Toutes dates',
                      isSelected: _selectedDateFilter == DashboardDateFilter.all,
                      onTap: () {
                        setState(() {
                          _selectedDateFilter = DashboardDateFilter.all;
                          _customStartDate = null;
                          _customEndDate = null;
                          _future = _load();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: "Aujourd'hui",
                      isSelected: _selectedDateFilter == DashboardDateFilter.today,
                      onTap: () {
                        setState(() {
                          _selectedDateFilter = DashboardDateFilter.today;
                          _customStartDate = null;
                          _customEndDate = null;
                          _future = _load();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '7 derniers jours',
                      isSelected: _selectedDateFilter == DashboardDateFilter.last7days,
                      onTap: () {
                        setState(() {
                          _selectedDateFilter = DashboardDateFilter.last7days;
                          _customStartDate = null;
                          _customEndDate = null;
                          _future = _load();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '30 derniers jours',
                      isSelected: _selectedDateFilter == DashboardDateFilter.last30days,
                      onTap: () {
                        setState(() {
                          _selectedDateFilter = DashboardDateFilter.last30days;
                          _customStartDate = null;
                          _customEndDate = null;
                          _future = _load();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: _selectedDateFilter == DashboardDateFilter.custom && _customStartDate != null
                          ? '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}'
                          : 'Personnalisé...',
                      isSelected: _selectedDateFilter == DashboardDateFilter.custom,
                      color: AppColors.primary,
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2025),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: _customStartDate != null && _customEndDate != null
                              ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
                              : null,
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDateFilter = DashboardDateFilter.custom;
                            _customStartDate = picked.start;
                            _customEndDate = picked.end;
                            _future = _load();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Chiffre d'Affaires (Turnover) Hero Widget
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF065F46), Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.payments_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "Chiffre d'affaires",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${data.revenue.toStringAsFixed(0)} F',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Revenu des commandes livrées uniquement',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            value: deliveryRate / 100,
                            strokeWidth: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${deliveryRate.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'LIVRÉES',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Insight Chips
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _InsightChip(
                      icon: Icons.rocket_launch_outlined,
                      label: 'Taux Livraison ${deliveryRate.toStringAsFixed(1)}%',
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 10),
                    _InsightChip(
                      icon: Icons.cancel_outlined,
                      label: 'Taux Annulation ${cancelRate.toStringAsFixed(1)}%',
                      color: const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 10),
                    _InsightChip(
                      icon: Icons.receipt_long_outlined,
                      label: '$activeOrders Commande(s) Active(s)',
                      color: const Color(0xFF6366F1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Grid of cards
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _ModernStatCard(
                    title: 'Commandes',
                    value: '${data.totalOrders}',
                    icon: Icons.shopping_bag_outlined,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                  ),
                  _ModernStatCard(
                    title: 'Clients',
                    value: '${data.totalClients}',
                    icon: Icons.people_outline,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                  ),
                  _ModernStatCard(
                    title: 'Livrées',
                    value: '${data.deliveredOrders}',
                    icon: Icons.check_circle_outline,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF047857)],
                    ),
                  ),
                  _ModernStatCard(
                    title: 'Annulées',
                    value: '${data.cancelledOrders}',
                    icon: Icons.cancel_outlined,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Progression rings
              Text(
                'Statut des commandes',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 20,
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    _StatusProgressRing(
                      label: 'En attente',
                      value: data.pendingOrders,
                      total: data.totalOrders,
                      color: Colors.amber,
                    ),
                    _StatusProgressRing(
                      label: 'En cours',
                      value: data.processingOrders,
                      total: data.totalOrders,
                      color: Colors.cyan,
                    ),
                    _StatusProgressRing(
                      label: 'Expédiées',
                      value: data.shippedOrders,
                      total: data.totalOrders,
                      color: Colors.blue,
                    ),
                    _StatusProgressRing(
                      label: 'Livrées',
                      value: data.deliveredOrders,
                      total: data.totalOrders,
                      color: const Color(0xFF10B981),
                    ),
                    _StatusProgressRing(
                      label: 'Annulées',
                      value: data.cancelledOrders,
                      total: data.totalOrders,
                      color: const Color(0xFFF43F5E),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Analyses & Performance section
              Text(
                'Analyses & Performance',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tab selector inside the card
                    Row(
                      children: [
                        _buildTabButton(
                          label: 'Finances',
                          active: _dashboardTab == 'finances',
                          onTap: () => setState(() => _dashboardTab = 'finances'),
                        ),
                        const SizedBox(width: 8),
                        _buildTabButton(
                          label: 'Top Ventes',
                          active: _dashboardTab == 'performance',
                          onTap: () => setState(() => _dashboardTab = 'performance'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    if (_dashboardTab == 'finances') ...[
                      // Grid of CA, Cost, Net Profit, Margin %
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Chiffre d\'Aff.',
                              value: '${_formatPrice(data.periodRevenue)} F',
                              color: Colors.blue,
                              icon: Icons.trending_up_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Coût d\'Achat',
                              value: '${_formatPrice(data.periodCost)} F',
                              color: Colors.orange,
                              icon: Icons.shopping_bag_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Bénéfice Net',
                              value: '${_formatPrice(data.periodProfit)} F',
                              color: const Color(0xFF55D80F),
                              icon: Icons.monetization_on_outlined,
                              isBold: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Marge Moyenne',
                              value: '${data.periodMargin.toStringAsFixed(1)}%',
                              color: const Color(0xFF8B5CF6),
                              icon: Icons.percent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(height: 1.5, color: AppColors.border),
                      const SizedBox(height: 12),

                      // Stock valuation
                      const Text(
                        'Valorisation du Stock Actuel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mutedText,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildValuationItem(
                            label: 'Valeur d\'Achat',
                            value: '${_formatPrice(data.stockValueAchat)} F',
                          ),
                          _buildValuationItem(
                            label: 'Valeur de Vente',
                            value: '${_formatPrice(data.stockValueVente)} F',
                          ),
                          _buildValuationItem(
                            label: 'Bénéf. Potentiel',
                            value: '${_formatPrice(data.stockProfitPotential)} F',
                            color: const Color(0xFF55D80F),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Performance Top Products Tab
                      if (data.topProducts.isEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.analytics_outlined, color: AppColors.mutedText, size: 36),
                                SizedBox(height: 10),
                                Text(
                                  'Aucune vente enregistrée.',
                                  style: TextStyle(
                                    color: AppColors.mutedText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Top 5 Produits les Plus Vendus',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mutedText,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.topProducts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final item = data.topProducts[idx];
                            final maxQty = data.topProducts.first.quantity;
                            final ratio = maxQty > 0 ? item.quantity / maxQty : 0.0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Rank circle
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: idx == 0
                                            ? Colors.amber.withValues(alpha: 0.12)
                                            : (idx == 1
                                                ? Colors.grey.withValues(alpha: 0.12)
                                                : (idx == 2
                                                    ? Colors.brown.withValues(alpha: 0.12)
                                                    : AppColors.background)),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${idx + 1}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: idx == 0
                                                ? Colors.amber
                                                : (idx == 1
                                                    ? Colors.grey.shade700
                                                    : (idx == 2
                                                        ? Colors.brown
                                                        : AppColors.text)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${item.quantity} vendus',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Progress bar showing proportional sales
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: Container(
                                    height: 4,
                                    width: double.infinity,
                                    color: Colors.grey.shade100,
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: ratio,
                                      child: Container(
                                        color: idx == 0 ? Colors.amber : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'CA : ${_formatPrice(item.revenue)} F',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.mutedText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Bénéfice : +${_formatPrice(item.profit)} F',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: item.profit >= 0 ? const Color(0xFF55D80F) : Colors.red,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModernStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InsightChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
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
  final List<_ProductPerformance> topProducts;
  final double periodRevenue;
  final double periodCost;
  final double periodProfit;
  final double periodMargin;
  final double stockValueAchat;
  final double stockValueVente;
  final double stockProfitPotential;

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
    required this.periodRevenue,
    required this.periodCost,
    required this.periodProfit,
    required this.periodMargin,
    required this.stockValueAchat,
    required this.stockValueVente,
    required this.stockProfitPotential,
  });
}

class _ProductPerformance {
  final String name;
  int quantity;
  double revenue;
  double profit;

  _ProductPerformance({
    required this.name,
    this.quantity = 0,
    this.revenue = 0.0,
    this.profit = 0.0,
  });
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.accent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _StatusProgressRing extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _StatusProgressRing({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final rate = total > 0 ? value / total : 0.0;
    final percentage = (rate * 100).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: rate,
                strokeWidth: 5,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          '$value u.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w700,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

