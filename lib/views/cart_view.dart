import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user_model.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../providers/cart_provider.dart';
import '../services/app_users_service.dart';
import '../services/order_items_service.dart';
import '../services/orders_service.dart';
import '../services/stocks_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/app_button.dart';

class CartView extends StatefulWidget {
  final VoidCallback? onCheckout;

  const CartView({super.key, this.onCheckout});

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  final _ordersService = OrdersService();
  final _orderItemsService = OrderItemsService();
  final _usersService = AppUsersService();
  final _stocksService = StocksService();

  bool _loading = false;

  Future<String?> _askDeliveryAddress() async {
    final controller = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Adresse de livraison'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Ex: Cocody, Rue 12, Maison 45',
            ),
            textInputAction: TextInputAction.done,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    return result;
  }

  Future<void> _checkout() async {
    if (_loading) return;

    final cart = context.read<CartProvider>();
    if (cart.totalItems == 0) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter pour commander.'),
        ),
      );
      return;
    }

    await _ensureUserRow(user);
    final appUser = await _usersService.resolveForAuthUser(
      authUserId: user.id,
      email: user.email,
    );

    if (!mounted) return;
    if (appUser?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de retrouver votre profil client pour créer la commande.',
          ),
        ),
      );
      return;
    }

    final address = await _askDeliveryAddress();
    if (!mounted) return;
    if (address == null) return;

    setState(() => _loading = true);

    try {
      final order = await _ordersService.create(
        OrderModel(
          userId: appUser!.id,
          status: 'pending',
          totalPrice: cart.totalPrice,
          deliveryAddress: address.isEmpty ? null : address,
        ),
      );

      final orderId = order.id;
      if (orderId == null) {
        throw StateError('Order id is null after creation.');
      }

      for (final item in cart.items) {
        final productId = item.product.id;
        if (productId == null) continue;

        await _orderItemsService.create(
          OrderItemModel(
            orderId: orderId,
            productId: productId,
            quantity: item.quantity,
            price: item.effectivePrice,
          ),
        );
      }

      for (final item in cart.items) {
        final pid = item.product.id;
        if (pid != null) {
          await _stocksService.decrementStock(pid, item.quantity);
        }
      }

      cart.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande créée avec succès.')),
      );
      widget.onCheckout?.call();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final message = switch (e) {
        PostgrestException ex => ex.message,
        StorageException ex => ex.message,
        AuthException ex => ex.message,
        _ => e.toString(),
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur commande: $message')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureUserRow(User user) async {
    try {
      final existing = await _usersService.resolveForAuthUser(
        authUserId: user.id,
        email: user.email,
      );
      if (existing != null) return;

      final email = user.email;
      if (email == null || email.trim().isEmpty) return;

      await _usersService.create(
        AppUserModel(
          id: user.id,
          email: email,
          name: (user.userMetadata?['name'] as String?)?.trim().isEmpty ?? true
              ? null
              : (user.userMetadata?['name'] as String?),
          phone: (user.userMetadata?['phone'] as String?),
          roleId: null,
          isActive: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CartView] _ensureUserRow error=$e');
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Panier',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: cart.totalItems == 0 ? null : cart.clear,
            child: const Text('Vider'),
          ),
        ],
      ),
      body: cart.totalItems == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      size: 58,
                      color: AppColors.mutedText,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Ton panier est vide',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ajoute des produits depuis le catalogue.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.padding,
                10,
                AppSizes.padding,
                140,
              ),
              children: [
                ...cart.items.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSizes.radius),
                          child: Container(
                            width: 64,
                            height: 64,
                            color: AppColors.background,
                            child: (item.product.imageUrl ?? '').trim().isEmpty
                                ? const Icon(
                                    Icons.image_outlined,
                                    color: AppColors.mutedText,
                                  )
                                : Image.network(
                                    item.product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.mutedText,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${item.effectivePrice.toStringAsFixed(0)} F',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              if (item.effectivePrice < item.product.price)
                                Text(
                                  '${item.product.price.toStringAsFixed(0)} F',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: AppColors.mutedText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => cart.decrement(item.product),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '${item.quantity}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        IconButton(
                          onPressed: () => cart.increment(item.product),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomSheet: cart.totalItems == 0
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(AppSizes.padding),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        Text(
                          '${cart.totalPrice.toStringAsFixed(0)} F',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.accent,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'Passer la commande',
                      loading: _loading,
                      onPressed: _loading ? null : _checkout,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
