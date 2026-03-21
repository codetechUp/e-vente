import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../services/order_items_service.dart';
import '../services/orders_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';

class OrderDetailsView extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsView({super.key, required this.order});

  @override
  State<OrderDetailsView> createState() => _OrderDetailsViewState();
}

class _OrderDetailsViewState extends State<OrderDetailsView> {
  final _ordersService = OrdersService();
  final _itemsService = OrderItemsService();

  bool _loading = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
  }

  Future<void> _saveStatus() async {
    final id = widget.order.id;
    if (id == null) return;

    setState(() => _loading = true);
    try {
      await _ordersService.updateById(id, {'status': _status});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Statut mis à jour.')));
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _InfoRow(label: 'Statut', value: order.status),
                _InfoRow(
                  label: 'Total',
                  value: '${(order.totalPrice ?? 0).toStringAsFixed(0)} F',
                ),
                _InfoRow(label: 'Adresse', value: order.deliveryAddress ?? '-'),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Changer le statut',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('pending')),
                    DropdownMenuItem(
                      value: 'confirmed',
                      child: Text('confirmed'),
                    ),
                    DropdownMenuItem(
                      value: 'shipping',
                      child: Text('shipping'),
                    ),
                    DropdownMenuItem(
                      value: 'delivered',
                      child: Text('delivered'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('cancelled'),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _status = v ?? 'pending'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: FilledButton(
                    onPressed: _loading ? null : _saveStatus,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
