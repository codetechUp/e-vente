import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../models/app_user_model.dart';
import '../services/notification_service.dart';
import '../services/orders_service.dart';
import '../services/order_items_service.dart';
import '../services/app_users_service.dart';
import '../utils/constants/app_colors.dart';

class PreparateurOrdersView extends StatefulWidget {
  const PreparateurOrdersView({super.key});

  @override
  State<PreparateurOrdersView> createState() => _PreparateurOrdersViewState();
}

class _PreparateurOrdersViewState extends State<PreparateurOrdersView>
    with SingleTickerProviderStateMixin {
  final _ordersService = OrdersService();
  final _orderItemsService = OrderItemsService();
  final _usersService = AppUsersService();

  List<OrderModel> _orders = [];
  List<AppUserModel> _livreurs = [];
  bool _loading = true;
  late TabController _tabController;

  static const _tabs = ['En attente', 'En préparation', 'Prêt'];
  static const _statuses = ['pending', 'preparing', 'ready'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orders = await _ordersService.getAll();
      final allUsers = await _usersService.getAll();
      final livreurs = allUsers.where((u) => u.roleId != null).toList();

      final livreurRoleRows = await Supabase.instance.client
          .from('roles')
          .select('id')
          .eq('name', 'livreur')
          .maybeSingle();
      final livreurRoleId = livreurRoleRows?['id'] as int?;
      final filteredLivreurs = livreurRoleId != null
          ? allUsers.where((u) => u.roleId == livreurRoleId).toList()
          : livreurs;

      setState(() {
        _orders = orders
            .where(
              (o) =>
                  o.status == 'pending' ||
                  o.status == 'preparing' ||
                  o.status == 'ready',
            )
            .toList();
        _livreurs = filteredLivreurs;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<OrderModel> _filteredOrders(String status) =>
      _orders.where((o) => o.status == status).toList();

  Future<void> _updateStatus(OrderModel order, String newStatus) async {
    if (order.id == null) return;
    await _ordersService.updateById(order.id!, {'status': newStatus});
    final notif = NotificationService();
    final id = order.id!;
    switch (newStatus) {
      case 'preparing':
        await notif.notifyCommandeEnPreparation(orderId: id);
        break;
      case 'ready':
        await notif.notifyCommandePrete(orderId: id);
        break;
      case 'delivered':
        await notif.notifyCommandeLivree(orderId: id);
        break;
      case 'cancelled':
        await notif.notifyCommandeAnnulee(orderId: id);
        break;
    }
    await _load();
  }

  Future<void> _assignLivreur(OrderModel order) async {
    if (order.id == null) return;

    final selected = await showDialog<AppUserModel?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assigner un livreur'),
        content: _livreurs.isEmpty
            ? const Text('Aucun livreur disponible.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _livreurs.length,
                  itemBuilder: (_, i) {
                    final l = _livreurs[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          (l.name ?? l.email)[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(l.name ?? l.email),
                      subtitle: Text(l.phone ?? ''),
                      onTap: () => Navigator.of(ctx).pop(l),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (selected == null || selected.id == null) return;
    await _ordersService.updateById(order.id!, {
      'assigned_livreur_id': selected.id,
      'status': 'ready',
    });
    final notif = NotificationService();
    await notif.notifyCommandePrete(orderId: order.id!);
    await notif.notifyNouvelleDemandelivraison(
      orderId: order.id!,
      clientName: order.userName ?? order.userNom ?? 'Client',
      address: order.deliveryAddress,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Livreur ${selected.name ?? selected.email} assigné avec succès.',
          ),
        ),
      );
    }
    await _load();
  }

  Future<List<OrderItemModel>> _loadItems(int orderId) =>
      _orderItemsService.getAllForOrder(orderId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Commandes à préparer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.asMap().entries.map((e) {
            final count = _filteredOrders(_statuses[e.key]).length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.value),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _statuses
                  .map(
                    (s) => _OrderList(
                      orders: _filteredOrders(s),
                      status: s,
                      livreurs: _livreurs,
                      onUpdateStatus: _updateStatus,
                      onAssignLivreur: _assignLivreur,
                      loadItems: _loadItems,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final String status;
  final List<AppUserModel> livreurs;
  final Future<void> Function(OrderModel, String) onUpdateStatus;
  final Future<void> Function(OrderModel) onAssignLivreur;
  final Future<List<OrderItemModel>> Function(int) loadItems;

  const _OrderList({
    required this.orders,
    required this.status,
    required this.livreurs,
    required this.onUpdateStatus,
    required this.onAssignLivreur,
    required this.loadItems,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune commande ici',
              style: TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (_, i) => _OrderCard(
          order: orders[i],
          status: status,
          livreurs: livreurs,
          onUpdateStatus: onUpdateStatus,
          onAssignLivreur: onAssignLivreur,
          loadItems: loadItems,
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final String status;
  final List<AppUserModel> livreurs;
  final Future<void> Function(OrderModel, String) onUpdateStatus;
  final Future<void> Function(OrderModel) onAssignLivreur;
  final Future<List<OrderItemModel>> Function(int) loadItems;

  const _OrderCard({
    required this.order,
    required this.status,
    required this.livreurs,
    required this.onUpdateStatus,
    required this.onAssignLivreur,
    required this.loadItems,
  });

  Color get _statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return AppColors.primary;
      case 'ready':
        return Colors.green;
      default:
        return AppColors.mutedText;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'preparing':
        return 'En préparation';
      case 'ready':
        return 'Prêt';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final desiredDate = order.desiredDeliveryDate;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '#${order.id}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _statusColor,
                fontSize: 11,
              ),
            ),
          ),
        ),
        title: Text(
          order.userName ?? order.userEmail ?? 'Client inconnu',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order.userPhone != null)
              Text(
                order.userPhone!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedText,
                ),
              ),
            if (order.deliveryAddress != null)
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: AppColors.mutedText,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      order.deliveryAddress!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (desiredDate != null)
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Livraison le ${desiredDate.day.toString().padLeft(2, '0')}/${desiredDate.month.toString().padLeft(2, '0')}/${desiredDate.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: _statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${order.totalPrice?.toStringAsFixed(0) ?? '0'} F',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          FutureBuilder<List<OrderItemModel>>(
            future: order.id != null ? loadItems(order.id!) : Future.value([]),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                );
              }
              final items = snap.data ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (items.isNotEmpty) ...[
                    const Text(
                      'Produits commandés :',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: AppColors.mutedText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.productName ?? 'Produit'} × ${item.quantity}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              '${((item.price ?? 0) * item.quantity).toStringAsFixed(0)} F',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 16),
                  ],
                  if (order.assignedLivreurId != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delivery_dining,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Livreur : ${order.assignedLivreurName ?? order.assignedLivreurId}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildActions(context),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'pending')
          ElevatedButton.icon(
            onPressed: () => onUpdateStatus(order, 'preparing'),
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Commencer la préparation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        if (status == 'preparing') ...[
          ElevatedButton.icon(
            onPressed: () => onAssignLivreur(order),
            icon: const Icon(Icons.delivery_dining, size: 16),
            label: const Text('Assigner livreur & Marquer prêt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
        if (status == 'ready')
          OutlinedButton.icon(
            onPressed: () => onUpdateStatus(order, 'delivered'),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Marquer livré'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
