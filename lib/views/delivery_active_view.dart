import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/delivery_model.dart';
import '../providers/deliveries_provider.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import 'delivery_details_view.dart';

class DeliveryActiveView extends StatelessWidget {
  const DeliveryActiveView({super.key});

  Future<void> _markDelivered(
    BuildContext context,
    DeliveryModel delivery,
  ) async {
    try {
      await context.read<DeliveriesProvider>().markAsDelivered(delivery);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Livraison marquée comme livrée')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveriesProvider>();
    final deliveries = provider.activeDeliveries;
    final loading = provider.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Livraisons en cours',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.brandSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.loadDeliveries(),
              child: deliveries.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(AppSizes.paddingLg),
                      children: [
                        const SizedBox(height: 60),
                        const Icon(
                          Icons.local_shipping_outlined,
                          size: 80,
                          color: AppColors.mutedText,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Aucune livraison en cours',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Les livraisons acceptées apparaîtront ici.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: deliveries.length,
                      itemBuilder: (context, index) {
                        final d = deliveries[index];
                        return _ActiveDeliveryCard(
                          delivery: d,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DeliveryDetailsView(delivery: d),
                              ),
                            );
                          },
                          onMarkDelivered: () => _markDelivered(context, d),
                        );
                      },
                    ),
            ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  final DeliveryModel delivery;
  final VoidCallback onTap;
  final VoidCallback onMarkDelivered;

  const _ActiveDeliveryCard({
    required this.delivery,
    required this.onTap,
    required this.onMarkDelivered,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
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
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commande #${delivery.orderId ?? '-'}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'En cours de livraison',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Expédiée',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.blue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (delivery.deliveryAddress != null &&
                delivery.deliveryAddress!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFFFF8C00),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        delivery.deliveryAddress!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (delivery.orderItems != null &&
                delivery.orderItems!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          size: 16,
                          color: AppColors.mutedText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Produits (${delivery.orderItems!.length})',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        if (delivery.totalPrice != null)
                          Text(
                            '${delivery.totalPrice!.toStringAsFixed(0)} FCFA',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...delivery.orderItems!.take(3).map((item) {
                      final productName = item['products'] != null
                          ? (item['products'] as Map)['name'] as String?
                          : null;
                      final quantity = item['quantity'] as int?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${productName ?? 'Produit'} x$quantity',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (delivery.orderItems!.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+${delivery.orderItems!.length - 3} autre(s)',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onMarkDelivered,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Marquer comme livrée',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
