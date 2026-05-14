import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../models/app_user_model.dart';
import '../models/delivery_model.dart';
import '../models/order_model.dart';
import '../services/deliveries_service.dart';
import '../services/order_items_service.dart';
import '../services/orders_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/info_row.dart';

const _statusList = [
  'pending',
  'processing',
  'shipped',
  'delivered',
  'cancelled',
];

String statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'En attente';
    case 'processing':
      return 'En cours de traitement';
    case 'shipped':
      return 'Expédiée';
    case 'delivered':
      return 'Livrée';
    case 'cancelled':
      return 'Annulée';
    default:
      return status;
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'delivered':
      return AppColors.success;
    case 'shipped':
      return const Color(0xFF3B82F6);
    case 'processing':
      return AppColors.accent;
    case 'cancelled':
      return AppColors.danger;
    default:
      return AppColors.mutedText;
  }
}

IconData statusIcon(String status) {
  switch (status) {
    case 'delivered':
      return Icons.check_circle;
    case 'shipped':
      return Icons.local_shipping;
    case 'processing':
      return Icons.hourglass_empty;
    case 'cancelled':
      return Icons.cancel;
    default:
      return Icons.pending;
  }
}

class OrderDetailsView extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsView({super.key, required this.order});

  @override
  State<OrderDetailsView> createState() => _OrderDetailsViewState();
}

class _OrderDetailsViewState extends State<OrderDetailsView> {
  final _ordersService = OrdersService();
  final _itemsService = OrderItemsService();
  final _deliveriesService = DeliveriesService();

  bool _loading = false;
  late String _status;

  List<AppUserModel> _livreurs = [];
  String? _selectedLivreurId;
  String? _currentLivreurId;

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
    _loadLivreurs();
    _loadCurrentDelivery();
  }

  Future<void> _loadLivreurs() async {
    try {
      final rows = await Supabase.instance.client
          .from('users')
          .select('*, roles(name)')
          .order('name', ascending: true);

      final all = (rows as List)
          .cast<Map<String, dynamic>>()
          .map((e) => AppUserModel.fromJson(e))
          .toList();

      final livreurRoleRows = await Supabase.instance.client
          .from('roles')
          .select()
          .ilike('name', 'livreur')
          .maybeSingle();

      if (livreurRoleRows == null) return;
      final livreurRoleId = livreurRoleRows['id'] as int?;
      if (livreurRoleId == null) return;

      if (!mounted) return;
      setState(() {
        final uniqueLivreurs = <String, AppUserModel>{};
        for (final user in all) {
          final userId = user.id;
          if (user.roleId != livreurRoleId ||
              !user.isActive ||
              userId == null) {
            continue;
          }
          uniqueLivreurs[userId] = user;
        }

        _livreurs = uniqueLivreurs.values.toList()
          ..sort(
            (a, b) => ((a.name?.trim().isNotEmpty ?? false) ? a.name! : a.email)
                .toLowerCase()
                .compareTo(
                  ((b.name?.trim().isNotEmpty ?? false) ? b.name! : b.email)
                      .toLowerCase(),
                ),
          );
      });
    } catch (_) {}
  }

  Future<void> _loadCurrentDelivery() async {
    final orderId = widget.order.id;
    if (orderId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('deliveries')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();
      if (row != null) {
        final d = DeliveryModel.fromJson(row);
        if (!mounted) return;
        setState(() {
          _selectedLivreurId = d.deliveryPersonId;
          _currentLivreurId = d.deliveryPersonId;
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final id = widget.order.id;
    if (id == null) return;

    setState(() => _loading = true);
    try {
      await _ordersService.updateById(id, {'status': _status});

      if (_selectedLivreurId != null &&
          _selectedLivreurId != _currentLivreurId) {
        final existingRow = await Supabase.instance.client
            .from('deliveries')
            .select()
            .eq('order_id', id)
            .maybeSingle();

        if (existingRow != null) {
          final existingId = existingRow['id'] as int;
          await _deliveriesService.updateById(existingId, {
            'delivery_person_id': _selectedLivreurId,
          });
        } else {
          await _deliveriesService.create(
            DeliveryModel(
              orderId: id,
              deliveryPersonId: _selectedLivreurId,
              status: _status == 'pending' ? 'pending' : _status,
            ),
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Commande mise à jour.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final livreurIds = _livreurs
        .map((l) => l.id)
        .whereType<String>()
        .toList(growable: false);
    final selectedLivreurValue =
        _selectedLivreurId != null &&
            livreurIds.where((id) => id == _selectedLivreurId).length == 1
        ? _selectedLivreurId
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Commande #${order.id ?? '-'}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.padding,
          10,
          AppSizes.padding,
          110,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor(order.status),
                  statusColor(order.status).withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: statusColor(order.status).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        statusIcon(order.status),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Commande #${order.id ?? '-'}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.createdAt != null
                                ? DateFormat(
                                    'dd MMM yyyy, HH:mm',
                                    'fr_FR',
                                  ).format(order.createdAt!)
                                : '-',
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Statut',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              statusLabel(order.status),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.payments_outlined,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Montant',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${(order.totalPrice ?? 0).toStringAsFixed(0)} F',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Adresse de livraison',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.deliveryAddress?.isNotEmpty == true
                                  ? order.deliveryAddress!
                                  : 'Non spécifiée',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.desiredDeliveryDate != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date de livraison souhaitée',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMM yyyy', 'fr_FR')
                                    .format(order.desiredDeliveryDate!),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Informations client',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (order.userNom?.isNotEmpty == true) ...[
                  InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Nom',
                    value: order.userNom!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (order.userEmail?.isNotEmpty == true) ...[
                  InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: order.userEmail!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (order.userPhone?.isNotEmpty == true) ...[
                  InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Téléphone',
                    value: order.userPhone!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (order.userAdresse?.isNotEmpty == true) ...[
                  InfoRow(
                    icon: Icons.home_outlined,
                    label: 'Adresse',
                    value: order.userAdresse!,
                  ),
                ],
                if (order.userNom?.isEmpty != false &&
                    order.userEmail?.isEmpty != false &&
                    order.userPhone?.isEmpty != false &&
                    order.userAdresse?.isEmpty != false)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Aucune information client disponible',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF55D80F), Color(0xFF1FAE3C)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Gestion de la commande',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Changer le statut',
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _status,
                      isExpanded: true,
                      isDense: true,
                      items: _statusList
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(statusLabel(s)),
                            ),
                          )
                          .toList(),
                      onChanged: _loading
                          ? null
                          : (v) => setState(() => _status = v ?? 'pending'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Assigner un livreur',
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedLivreurValue,
                      isExpanded: true,
                      isDense: true,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Aucun livreur'),
                        ),
                        ..._livreurs.map(
                          (l) => DropdownMenuItem<String?>(
                            value: l.id,
                            child: Text(
                              (l.name?.isNotEmpty ?? false) ? l.name! : l.email,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _loading
                          ? null
                          : (v) => setState(() => _selectedLivreurId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: FilledButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Articles commandés',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder(
                  future: order.id == null
                      ? Future.value(const [])
                      : _itemsService.getAllForOrder(order.id!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('Erreur: ${snapshot.error}'),
                      );
                    }

                    final items = snapshot.data ?? const [];
                    if (items.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(AppSizes.paddingLg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusLg,
                          ),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Aucun article',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        ...items.asMap().entries.map((entry) {
                          final i = entry.value;
                          final index = entry.key;
                          return Container(
                            margin: EdgeInsets.only(
                              bottom: index < items.length - 1 ? 12 : 0,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    color: AppColors.background,
                                    child: (i.productImageUrl?.isNotEmpty == true)
                                        ? Image.network(
                                            i.productImageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.image_outlined,
                                                  color: AppColors.mutedText,
                                                  size: 24,
                                                ),
                                          )
                                        : const Icon(
                                            Icons.image_outlined,
                                            color: AppColors.mutedText,
                                            size: 24,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        i.productName?.isNotEmpty == true
                                            ? i.productName!
                                            : 'Produit #${i.productId ?? '-'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${(i.price ?? 0).toStringAsFixed(0)} F × ${i.quantity}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.mutedText,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF55D80F),
                                        Color(0xFF1FAE3C),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${((i.price ?? 0) * i.quantity).toStringAsFixed(0)} F',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
