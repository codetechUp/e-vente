import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../services/order_items_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import 'order_details_view.dart';

const _trackingSteps = ['pending', 'processing', 'shipped', 'delivered'];

class OrderTrackingView extends StatelessWidget {
  final OrderModel order;

  const OrderTrackingView({super.key, required this.order});

  int _currentStep() {
    final idx = _trackingSteps.indexOf(order.status);
    if (order.status == 'cancelled') return -1;
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final isCancelled = order.status == 'cancelled';
    final step = _currentStep();
    final itemsService = OrderItemsService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Suivi #${order.id ?? '-'}',
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
          40,
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
                  'Total: ${(order.totalPrice ?? 0).toStringAsFixed(0)} F',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent,
                  ),
                ),
                if (order.deliveryAddress != null &&
                    order.deliveryAddress!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Adresse: ${order.deliveryAddress}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (order.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Créée le ${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Suivi de la commande',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          if (isCancelled)
            Container(
              padding: const EdgeInsets.all(AppSizes.paddingLg),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: AppColors.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cette commande a été annulée.',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_trackingSteps.length, (i) {
              final done = i <= step;
              final isActive = i == step;
              final isLast = i == _trackingSteps.length - 1;

              return _StepTile(
                label: statusLabel(_trackingSteps[i]),
                done: done,
                isActive: isActive,
                isLast: isLast,
              );
            }),
          const SizedBox(height: 20),
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
                : itemsService.getAllForOrder(order.id!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return Text(
                  'Aucun article',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }

              return Column(
                children: items
                    .map(
                      (i) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusLg,
                          ),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                i.productName ??
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
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String label;
  final bool done;
  final bool isActive;
  final bool isLast;

  const _StepTile({
    required this.label,
    required this.done,
    required this.isActive,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.accent
        : AppColors.mutedText.withValues(alpha: 0.4);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done ? AppColors.accent : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2.5),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                if (!isLast) Expanded(child: Container(width: 3, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                  color: done ? AppColors.text : AppColors.mutedText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
