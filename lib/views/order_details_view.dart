import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_model.dart';
import '../models/delivery_model.dart';
import '../models/order_model.dart';
import '../services/deliveries_service.dart';
import '../services/order_items_service.dart';
import '../services/orders_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';

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

class _HeroInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool fullWidth;

  const _HeroInfoChip({
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
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
            padding: const EdgeInsets.all(AppSizes.paddingLg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1ED9D2), Color(0xFF0FC2DA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Détails de la commande',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ID #${order.id ?? '-'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _HeroInfoChip(
                        label: 'Statut',
                        value: statusLabel(order.status),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroInfoChip(
                        label: 'Montant',
                        value:
                            '${(order.totalPrice ?? 0).toStringAsFixed(0)} F',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _HeroInfoChip(
                  label: 'Adresse',
                  value: order.deliveryAddress ?? '-',
                  fullWidth: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingLg),
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assignation & suivi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
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
          const SizedBox(height: 14),
          Text(
            'Articles',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
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
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Aucun article',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  ...items.map(
                    (i) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Produit #${i.productId ?? '-'}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            'x${i.quantity}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${((i.price ?? 0) * i.quantity).toStringAsFixed(0)} F',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
