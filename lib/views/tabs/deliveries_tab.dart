import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/delivery_model.dart';
import '../../services/app_users_service.dart';
import '../../services/deliveries_service.dart';
import '../../utils/constants/app_colors.dart';
import '../../utils/constants/app_sizes.dart';

class DeliveriesTab extends StatefulWidget {
  const DeliveriesTab({super.key});

  @override
  State<DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends State<DeliveriesTab> {
  final _deliveriesService = DeliveriesService();
  final _usersService = AppUsersService();

  late Future<List<DeliveryModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DeliveryModel>> _load() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return [];

    final appUser = await _usersService.resolveForAuthUser(
      authUserId: authUser.id,
      email: authUser.email,
    );
    if (appUser?.id == null) return [];

    final all = await _deliveriesService.getAll();
    return all.where((d) => d.deliveryPersonId == appUser!.id).toList();
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'processing':
        return 'En cours';
      case 'shipped':
        return 'Expédiée';
      case 'delivered':
        return 'Livrée';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppColors.success;
      case 'shipped':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      default:
        return AppColors.mutedText;
    }
  }

  Future<void> _updateStatus(DeliveryModel delivery, String newStatus) async {
    if (delivery.id == null) return;
    try {
      final patch = <String, dynamic>{'status': newStatus};
      if (newStatus == 'delivered') {
        patch['delivered_at'] = DateTime.now().toIso8601String();
      }
      await _deliveriesService.updateById(delivery.id!, patch);

      if (delivery.orderId != null) {
        await Supabase.instance.client
            .from('orders')
            .update({'status': newStatus})
            .eq('id', delivery.orderId!);
      }

      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statut mis à jour: ${_statusLabel(newStatus)}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<DeliveryModel>>(
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

          final deliveries = snapshot.data ?? [];

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1ED9D2), Color(0xFF0FC2DA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Livraisons',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Consultez les nouvelles commandes disponibles et gérez vos tournées.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: deliveries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.paddingLg),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.local_shipping_outlined,
                                size: 58,
                                color: AppColors.mutedText,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Aucune livraison',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Les commandes assignées apparaîtront ici.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.mutedText,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                        itemCount: deliveries.length,
                        itemBuilder: (context, index) {
                          final d = deliveries[index];
                          return _DeliveryTile(
                            delivery: d,
                            statusLabel: _statusLabel(d.status),
                            statusColor: _statusColor(d.status),
                            onMarkShipped:
                                d.status == 'pending' ||
                                    d.status == 'processing'
                                ? () => _updateStatus(d, 'shipped')
                                : null,
                            onMarkDelivered: d.status == 'shipped'
                                ? () => _updateStatus(d, 'delivered')
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  final DeliveryModel delivery;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback? onMarkShipped;
  final VoidCallback? onMarkDelivered;

  const _DeliveryTile({
    required this.delivery,
    required this.statusLabel,
    required this.statusColor,
    this.onMarkShipped,
    this.onMarkDelivered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2DFF30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.store_mall_directory,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Commande #${delivery.orderId ?? '-'}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FDFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FFFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mission',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppColors.mutedText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Livraison client assignée',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FDFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  delivery.orderId == null ? '-' : '#${delivery.orderId}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF00C7D4),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (delivery.deliveryAddress != null &&
              delivery.deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFFFF8C00),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adresse de livraison',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          delivery.deliveryAddress!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.text,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (delivery.deliveredAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Livrée le ${delivery.deliveredAt!.day}/${delivery.deliveredAt!.month}/${delivery.deliveredAt!.year}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (onMarkShipped != null || onMarkDelivered != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onMarkShipped != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onMarkShipped,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Accepter',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                if (onMarkShipped != null && onMarkDelivered != null)
                  const SizedBox(width: 8),
                if (onMarkDelivered != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onMarkDelivered,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF19DAD5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Livrée',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
