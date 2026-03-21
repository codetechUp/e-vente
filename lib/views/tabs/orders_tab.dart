import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/order_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/orders_service.dart';
import '../../utils/constants/app_colors.dart';
import '../../utils/constants/app_sizes.dart';
import '../cart_view.dart';
import '../order_details_view.dart';
import '../../widgets/badge_icon_button.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final _ordersService = OrdersService();

  late Future<List<OrderModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<OrderModel>> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const [];
    return _ordersService.getAllForUser(user.id);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<OrderModel>>(
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

          final orders = snapshot.data ?? const [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.padding,
              10,
              AppSizes.padding,
              110,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'Commandes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    color: AppColors.mutedText,
                    tooltip: 'Rafraîchir',
                  ),
                  const SizedBox(width: 6),
                  BadgeIconButton(
                    icon: Icons.shopping_cart_outlined,
                    badge: context.watch<CartProvider>().totalItems,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CartView()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (orders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingLg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 58,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Vous n'avez pas encore effectuer de commande !!!",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Merci de visiter notre catalogue pour commander des produits",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...orders.map(
                  (o) => InkWell(
                    onTap: () async {
                      final changed = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderDetailsView(order: o),
                        ),
                      );
                      if (changed == true) {
                        await _reload();
                      }
                    },
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Commande #${o.id ?? '-'}',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Statut: ${o.status}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.mutedText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${(o.totalPrice ?? 0).toStringAsFixed(0)} F',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.mutedText,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
