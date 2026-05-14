import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user_model.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../providers/cart_provider.dart';
import '../providers/orders_provider.dart';
import '../services/app_users_service.dart';
import '../services/order_items_service.dart';
import '../services/orders_service.dart';
import '../services/notification_service.dart';
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

  Future<Map<String, dynamic>?> _askDeliveryInfo() async {
    final addressController = TextEditingController();
    final now = DateTime.now();
    final isLate = now.hour >= 23;
    String? selectedSlot; // 'demain' or 'apres-demain'

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'Informations de livraison',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Info magasin ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gros divers est ouvert 7j/7',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '> Commander avant 21h pour une livraison demain',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --- Checkbox OK ---
                    InkWell(
                      onTap: () {
                        // Lecture seule, toujours OK
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.accent,
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.check,
                                size: 14,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'OK',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Heure Livraison Préférée ---
                    const Text(
                      'Heure Livraison Préférée',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Si une option n'apparaît pas, la capacité de Gros divers est déjà atteinte",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Option Demain (seulement si heure < 23h)
                    if (!isLate)
                      _DeliverySlotOption(
                        label: 'Demain (8h-19h)',
                        selected: selectedSlot == 'demain',
                        onTap: () => setStateDialog(() => selectedSlot = 'demain'),
                      ),
                    // Option Après-Demain
                    _DeliverySlotOption(
                      label: 'Après-Demain (8h-19h)',
                      selected: selectedSlot == 'apres-demain',
                      onTap: () => setStateDialog(() => selectedSlot = 'apres-demain'),
                    ),
                    const SizedBox(height: 14),

                    // --- Adresse de livraison ---
                    const Text(
                      'Adresse de livraison',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        hintText: 'Ex: Dakar, Grand Mbao, Rue 12',
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop({
                    'address': addressController.text.trim(),
                    'slot': selectedSlot,
                  }),
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
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

    final deliveryInfo = await _askDeliveryInfo();
    if (!mounted) return;
    if (deliveryInfo == null) return;

    final address = deliveryInfo['address'] as String?;
    final slot = deliveryInfo['slot'] as String?;

    // Calculer la date de livraison à partir du créneau choisi
    DateTime? desiredDate;
    if (slot != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (slot == 'demain') {
        desiredDate = today.add(const Duration(days: 1));
      } else if (slot == 'apres-demain') {
        desiredDate = today.add(const Duration(days: 2));
      }
    }

    setState(() => _loading = true);

    try {
      final order = await _ordersService.create(
        OrderModel(
          userId: appUser!.id,
          status: 'pending',
          totalPrice: cart.totalPrice,
          deliveryAddress: (address?.isEmpty ?? true) ? null : address,
          desiredDeliveryDate: desiredDate,
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

      // Notification client : commande confirmée
      await NotificationService().notifyCommandeConfirmee(orderId: orderId);

      if (!mounted) return;

      // Mettre à jour la liste des commandes via le provider
      context.read<OrdersProvider>().loadOrders();

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
                  (item) => Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 34),
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
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          onPressed: () => cart.remove(item.product),
                          icon: const Icon(Icons.delete_outline),
                          color: AppColors.danger,
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: 'Supprimer',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomSheet: cart.totalItems == 0
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.padding,
                  AppSizes.padding,
                  AppSizes.padding,
                  AppSizes.padding + MediaQuery.of(context).padding.bottom,
                ),
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

class _DeliverySlotOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _DeliverySlotOption({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.accent : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
            color: selected ? AppColors.accent.withValues(alpha: 0.06) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.accent : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Center(
                        child: Icon(
                          Icons.circle,
                          size: 11,
                          color: AppColors.accent,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? AppColors.accent : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
