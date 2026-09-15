import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user_model.dart';
import '../models/category_model.dart';
import '../models/delivery_setting_model.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/promotion_model.dart';
import '../providers/orders_provider.dart';
import '../services/categories_service.dart';
import '../services/delivery_settings_service.dart';
import '../services/notification_service.dart';
import '../services/order_items_service.dart';
import '../services/orders_service.dart';
import '../services/products_service.dart';
import '../services/promotions_service.dart';
import '../services/stocks_service.dart';
import '../utils/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _CartItem {
  final ProductModel product;
  final double effectivePrice;
  int quantity;

  _CartItem({
    required this.product,
    required this.effectivePrice,
    this.quantity = 1,
  });

  double get total => effectivePrice * quantity;
}

class _PageData {
  final List<ProductModel> products;
  final List<CategoryModel> categories;
  final Map<int, int> promoMap; // productId → discountPercent
  final List<DeliverySettingModel> deliverySettings;

  const _PageData({
    required this.products,
    required this.categories,
    required this.promoMap,
    required this.deliverySettings,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN VIEW
// ─────────────────────────────────────────────────────────────────────────────

class AdminCreateOrderView extends StatefulWidget {
  final AppUserModel client;

  const AdminCreateOrderView({super.key, required this.client});

  @override
  State<AdminCreateOrderView> createState() => _AdminCreateOrderViewState();
}

class _AdminCreateOrderViewState extends State<AdminCreateOrderView>
    with TickerProviderStateMixin {
  // Services
  final _productsService = ProductsService();
  final _categoriesService = CategoriesService();
  final _promotionsService = PromotionsService();
  final _deliveryService = DeliverySettingsService();
  final _ordersService = OrdersService();
  final _orderItemsService = OrderItemsService();
  final _stocksService = StocksService();

  // State
  late Future<_PageData> _future;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int? _selectedCategoryId;

  // Cart
  final List<_CartItem> _cart = [];

  // Checkout fields
  late TextEditingController _addressCtrl;
  String? _selectedSlotValue; // "DD/MM/YYYY|HH:MM"

  // UI State
  bool _submitting = false;

  // Animations
  late AnimationController _cartBadgeAnim;
  late AnimationController _checkoutPanelAnim;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(text: widget.client.adresse ?? '');
    _future = _loadData();

    _cartBadgeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _checkoutPanelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _addressCtrl.dispose();
    _cartBadgeAnim.dispose();
    _checkoutPanelAnim.dispose();
    super.dispose();
  }

  Future<_PageData> _loadData() async {
    final results = await Future.wait([
      _productsService.getAll(),
      _categoriesService.getAll(),
      _promotionsService.getAll(),
      _deliveryService.getActiveSettings(),
    ]);

    final products = results[0] as List<ProductModel>;
    final categories = results[1] as List<CategoryModel>;
    final promos = results[2] as List<PromotionModel>;
    final settings = results[3] as List<DeliverySettingModel>;

    final now = DateTime.now();
    final promoMap = <int, int>{};
    for (final p in promos) {
      if (!p.isActive) continue;
      if (p.endDate != null && p.endDate!.isBefore(now)) continue;
      if (p.productId != null && p.discountPercent != null) {
        promoMap[p.productId!] = p.discountPercent!;
      }
    }

    return _PageData(
      products: products.where((p) => p.display).toList(),
      categories: categories,
      promoMap: promoMap,
      deliverySettings: settings,
    );
  }

  // ─── Cart helpers ───────────────────────────────────────────────────────────

  void _addToCart(ProductModel product, double effectivePrice) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == product.id);
      if (idx >= 0) {
        if (_cart[idx].quantity < product.stock) {
          _cart[idx].quantity++;
        }
      } else {
        if (product.stock > 0) {
          _cart.add(
            _CartItem(product: product, effectivePrice: effectivePrice),
          );
        }
      }
    });
    _cartBadgeAnim
      ..reset()
      ..forward();
  }

  void _removeFromCart(ProductModel product) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == product.id);
      if (idx >= 0) {
        if (_cart[idx].quantity > 1) {
          _cart[idx].quantity--;
        } else {
          _cart.removeAt(idx);
        }
      }
    });
  }

  void _deleteFromCart(int idx) {
    setState(() => _cart.removeAt(idx));
  }

  int _cartQty(int productId) {
    final idx = _cart.indexWhere((c) => c.product.id == productId);
    return idx >= 0 ? _cart[idx].quantity : 0;
  }

  int get _totalItems => _cart.fold(0, (s, c) => s + c.quantity);
  double get _totalPrice => _cart.fold(0, (s, c) => s + c.total);

  // ─── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) {
      _showSnack('Ajoutez au moins un article', isError: true);
      return;
    }
    if (_selectedSlotValue == null) {
      _showSnack('Veuillez sélectionner un créneau de livraison', isError: true);
      return;
    }
    if (widget.client.id == null) {
      _showSnack('Client invalide', isError: true);
      return;
    }

    DateTime? desiredDate;
    String? deliverySlot;
    if (_selectedSlotValue!.contains('|')) {
      final parts = _selectedSlotValue!.split('|');
      final dateParts = parts[0].split('/');
      deliverySlot = parts[1];
      desiredDate = DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
      );
    }

    setState(() => _submitting = true);

    try {
      final address = _addressCtrl.text.trim();

      // 1. Create order
      final order = await _ordersService.create(
        OrderModel(
          userId: widget.client.id,
          status: 'pending',
          totalPrice: _totalPrice,
          deliveryAddress: address.isEmpty ? null : address,
          desiredDeliveryDate: desiredDate,
          deliverySlot: deliverySlot,
        ),
      );

      final orderId = order.id;
      if (orderId == null) throw StateError('Order id is null after creation.');

      // 2. Create order items
      for (final item in _cart) {
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

      // 3. Decrement stocks
      for (final item in _cart) {
        final pid = item.product.id;
        if (pid != null) {
          await _stocksService.decrementStock(pid, item.quantity);
        }
      }

      // 4. Notification
      await NotificationService().notifyCommandeConfirmee(orderId: orderId);

      // 5. Refresh orders provider
      if (mounted) {
        context.read<OrdersProvider>().loadOrders();
      }

      if (mounted) {
        await _showSuccessDialog(orderId);
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessDialog(int orderId) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SuccessDialog(
        orderId: orderId,
        clientName: widget.client.name ?? widget.client.nom ?? 'Client',
        total: _totalPrice,
        itemCount: _totalItems,
        onDone: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 860;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_PageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          final data = snapshot.data!;

          if (isDesktop) {
            return _buildDesktopLayout(data);
          } else {
            return _buildMobileLayout(data);
          }
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DESKTOP LAYOUT
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(_PageData data) {
    return Column(
      children: [
        // Top header
        _ClientHeader(client: widget.client, isDesktop: true),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── LEFT: Catalog ──────────────────────────────────────────────
              Expanded(
                flex: 6,
                child: _CatalogPanel(
                  data: data,
                  searchCtrl: _searchCtrl,
                  searchQuery: _searchQuery,
                  selectedCategoryId: _selectedCategoryId,
                  cartQty: _cartQty,
                  onSearch: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  onCategorySelect: (id) => setState(() => _selectedCategoryId = id),
                  onAdd: _addToCart,
                  onRemove: _removeFromCart,
                ),
              ),

              // ── RIGHT: Order Summary ───────────────────────────────────────
              SizedBox(
                width: 380,
                child: _OrderSummaryPanel(
                  cart: _cart,
                  deliverySettings: data.deliverySettings,
                  addressCtrl: _addressCtrl,
                  selectedSlotValue: _selectedSlotValue,
                  submitting: _submitting,
                  clientName: widget.client.name ?? widget.client.nom,
                  totalItems: _totalItems,
                  totalPrice: _totalPrice,
                  onSlotSelected: (v) => setState(() => _selectedSlotValue = v),
                  onDeleteItem: _deleteFromCart,
                  onIncrement: (item) => _addToCart(item.product, item.effectivePrice),
                  onDecrement: (item) => _removeFromCart(item.product),
                  onSubmit: _submitOrder,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout(_PageData data) {
    return Stack(
      children: [
        Column(
          children: [
            _ClientHeader(client: widget.client, isDesktop: false),
            Expanded(
              child: _CatalogPanel(
                data: data,
                searchCtrl: _searchCtrl,
                searchQuery: _searchQuery,
                selectedCategoryId: _selectedCategoryId,
                cartQty: _cartQty,
                onSearch: (v) => setState(() => _searchQuery = v.toLowerCase()),
                onCategorySelect: (id) => setState(() => _selectedCategoryId = id),
                onAdd: _addToCart,
                onRemove: _removeFromCart,
              ),
            ),
            // Space for floating bar
            const SizedBox(height: 80),
          ],
        ),

        // Floating cart bar
        if (_totalItems > 0)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: AnimatedBuilder(
              animation: _cartBadgeAnim,
              builder: (ctx, child) {
                return Transform.scale(
                  scale: 1.0 + (_cartBadgeAnim.value * 0.03),
                  child: child,
                );
              },
              child: _FloatingCartBar(
                totalItems: _totalItems,
                totalPrice: _totalPrice,
                onTap: () {
                  _showMobileCheckout(data.deliverySettings);
                },
              ),
            ),
          ),
      ],
    );
  }

  void _showMobileCheckout(List<DeliverySettingModel> settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateSheet) {
          return _MobileCheckoutSheet(
            cart: _cart,
            deliverySettings: settings,
            addressCtrl: _addressCtrl,
            selectedSlotValue: _selectedSlotValue,
            submitting: _submitting,
            totalItems: _totalItems,
            totalPrice: _totalPrice,
            onSlotSelected: (v) {
              setStateSheet(() {});
              setState(() => _selectedSlotValue = v);
            },
            onDeleteItem: (idx) {
              setStateSheet(() => _cart.removeAt(idx));
              setState(() {});
            },
            onIncrement: (item) {
              setState(() {
                final i = _cart.indexWhere((c) => c.product.id == item.product.id);
                if (i >= 0 && _cart[i].quantity < item.product.stock) {
                  _cart[i].quantity++;
                }
              });
              setStateSheet(() {});
            },
            onDecrement: (item) {
              setState(() {
                final i = _cart.indexWhere((c) => c.product.id == item.product.id);
                if (i >= 0) {
                  if (_cart[i].quantity > 1) {
                    _cart[i].quantity--;
                  } else {
                    _cart.removeAt(i);
                  }
                }
              });
              setStateSheet(() {});
            },
            onSubmit: () async {
              Navigator.of(ctx).pop();
              await _submitOrder();
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLIENT HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ClientHeader extends StatelessWidget {
  final AppUserModel client;
  final bool isDesktop;

  const _ClientHeader({required this.client, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final displayName = client.name?.trim().isNotEmpty == true
        ? client.name!
        : (client.nom?.trim().isNotEmpty == true ? client.nom! : 'Client');

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppColors.text,
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),

          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              client.avatarLetter,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande pour $displayName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (client.phone != null || client.adresse != null)
                  Text(
                    [
                      if (client.phone != null) client.phone,
                      if (client.adresse != null && client.adresse!.isNotEmpty) client.adresse,
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Admin',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATALOG PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _CatalogPanel extends StatelessWidget {
  final _PageData data;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final int? selectedCategoryId;
  final int Function(int productId) cartQty;
  final ValueChanged<String> onSearch;
  final ValueChanged<int?> onCategorySelect;
  final void Function(ProductModel, double) onAdd;
  final void Function(ProductModel) onRemove;

  const _CatalogPanel({
    required this.data,
    required this.searchCtrl,
    required this.searchQuery,
    required this.selectedCategoryId,
    required this.cartQty,
    required this.onSearch,
    required this.onCategorySelect,
    required this.onAdd,
    required this.onRemove,
  });

  List<ProductModel> get _filtered {
    List<ProductModel> list;
    if (selectedCategoryId == -1) {
      list = data.products.where((p) => data.promoMap.containsKey(p.id)).toList();
    } else if (selectedCategoryId == null) {
      list = data.products;
    } else {
      list = data.products.where((p) => p.categoryId == selectedCategoryId).toList();
    }
    if (searchQuery.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(searchQuery)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _SearchBar(
            controller: searchCtrl,
            onChanged: onSearch,
          ),
        ),

        // Category chips
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            children: [
              _CategoryChip(
                label: 'Tout',
                active: selectedCategoryId == null,
                onTap: () => onCategorySelect(null),
              ),
              _CategoryChip(
                label: '🔥 Promos',
                active: selectedCategoryId == -1,
                onTap: () => onCategorySelect(-1),
              ),
              ...data.categories.where((c) => c.id != null).map((c) => _CategoryChip(
                    label: c.name,
                    active: selectedCategoryId == c.id,
                    onTap: () => onCategorySelect(c.id),
                  )),
            ],
          ),
        ),

        // Stats bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Text(
                '${filtered.length} produit${filtered.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // Product list
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    final discount = data.promoMap[p.id];
                    final qty = cartQty(p.id ?? -1);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ProductCard(
                        product: p,
                        discountPercent: discount,
                        cartQty: qty,
                        onAdd: onAdd,
                        onRemove: onRemove,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 54, color: AppColors.mutedText),
            SizedBox(height: 12),
            Text(
              'Aucun produit trouvé',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Modifiez votre recherche ou sélectionnez une autre catégorie.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final int? discountPercent;
  final int cartQty;
  final void Function(ProductModel, double) onAdd;
  final void Function(ProductModel) onRemove;

  const _ProductCard({
    required this.product,
    this.discountPercent,
    required this.cartQty,
    required this.onAdd,
    required this.onRemove,
  });

  bool get _hasPromo => discountPercent != null && discountPercent! > 0;

  double get _effectivePrice =>
      _hasPromo ? product.price * (1 - discountPercent! / 100) : product.price;

  Color get _stockColor {
    if (product.stock <= 0) return AppColors.danger;
    if (product.stock <= 5) return AppColors.warning;
    return AppColors.success;
  }

  String get _stockLabel {
    if (product.stock <= 0) return 'Épuisé';
    if (product.stock <= 5) return '${product.stock} restant${product.stock > 1 ? 's' : ''}';
    return 'En stock';
  }

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.stock <= 0;
    final canAdd = !isOutOfStock && cartQty < product.stock;

    return AnimatedOpacity(
      opacity: isOutOfStock ? 0.55 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cartQty > 0
                ? AppColors.brandGreen.withValues(alpha: 0.4)
                : AppColors.border,
            width: cartQty > 0 ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
              child: Stack(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    color: AppColors.background,
                    child: (product.imageUrl ?? '').trim().isEmpty
                        ? const Icon(
                            Icons.image_outlined,
                            size: 30,
                            color: AppColors.mutedText,
                          )
                        : Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              size: 30,
                              color: AppColors.mutedText,
                            ),
                          ),
                  ),
                  // Promo badge
                  if (_hasPromo)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '-$discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Price row
                    Row(
                      children: [
                        Text(
                          '${_effectivePrice.toStringAsFixed(0)} F',
                          style: TextStyle(
                            color: _hasPromo ? Colors.red : AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        if (_hasPromo) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${product.price.toStringAsFixed(0)} F',
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.mutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Stock badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _stockColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _stockLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _stockColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Quantity controls
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  // Qty badge or add button
                  if (cartQty == 0)
                    _AddButton(
                      enabled: canAdd,
                      onTap: canAdd ? () => onAdd(product, _effectivePrice) : null,
                    )
                  else
                    _QtyControl(
                      qty: cartQty,
                      canAdd: canAdd,
                      onAdd: () => onAdd(product, _effectivePrice),
                      onRemove: () => onRemove(product),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _AddButton({required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? AppColors.brandGreen : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.add_rounded,
          color: enabled ? Colors.white : Colors.grey.shade400,
          size: 20,
        ),
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  final int qty;
  final bool canAdd;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QtyControl({
    required this.qty,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.brandGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyBtn(icon: Icons.remove_rounded, onTap: onRemove),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$qty',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: AppColors.brandGreenDark,
              ),
            ),
          ),
          _QtyBtn(
            icon: Icons.add_rounded,
            onTap: canAdd ? onAdd : null,
            disabled: !canAdd,
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  const _QtyBtn({required this.icon, this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 16,
          color: disabled ? Colors.grey.shade400 : AppColors.brandGreenDark,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDER SUMMARY PANEL (DESKTOP RIGHT SIDE)
// ─────────────────────────────────────────────────────────────────────────────

class _OrderSummaryPanel extends StatefulWidget {
  final List<_CartItem> cart;
  final List<DeliverySettingModel> deliverySettings;
  final TextEditingController addressCtrl;
  final String? selectedSlotValue;
  final bool submitting;
  final String? clientName;
  final int totalItems;
  final double totalPrice;
  final ValueChanged<String?> onSlotSelected;
  final void Function(int idx) onDeleteItem;
  final void Function(_CartItem) onIncrement;
  final void Function(_CartItem) onDecrement;
  final VoidCallback onSubmit;

  const _OrderSummaryPanel({
    required this.cart,
    required this.deliverySettings,
    required this.addressCtrl,
    required this.selectedSlotValue,
    required this.submitting,
    required this.clientName,
    required this.totalItems,
    required this.totalPrice,
    required this.onSlotSelected,
    required this.onDeleteItem,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSubmit,
  });

  @override
  State<_OrderSummaryPanel> createState() => _OrderSummaryPanelState();
}

class _OrderSummaryPanelState extends State<_OrderSummaryPanel> {
  final _slotScrollCtrl = ScrollController();

  @override
  void dispose() {
    _slotScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: AppColors.brandGreen, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Résumé de commande',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                ),
                const Spacer(),
                if (widget.totalItems > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.totalItems} article${widget.totalItems > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              controller: _slotScrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                // Empty cart state
                if (widget.cart.isEmpty) ...[
                  const SizedBox(height: 40),
                  const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 52,
                          color: AppColors.mutedText,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Panier vide',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.mutedText,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Sélectionnez des produits dans le catalogue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Cart items
                  _SectionTitle(title: 'Articles sélectionnés', icon: Icons.list_alt_rounded),
                  const SizedBox(height: 8),
                  ...List.generate(widget.cart.length, (i) {
                    final item = widget.cart[i];
                    return _CartItemTile(
                      item: item,
                      onDelete: () => widget.onDeleteItem(i),
                      onIncrement: () => widget.onIncrement(item),
                      onDecrement: () => widget.onDecrement(item),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // Delivery address
                _SectionTitle(title: 'Adresse de livraison', icon: Icons.location_on_outlined),
                const SizedBox(height: 8),
                _StyledTextField(
                  controller: widget.addressCtrl,
                  hint: 'Ex: Parcelles Assainies U24, Dakar',
                  prefixIcon: Icons.home_outlined,
                ),
                const SizedBox(height: 16),

                // Delivery slots
                _SectionTitle(title: 'Créneau de livraison *', icon: Icons.schedule_outlined),
                const SizedBox(height: 8),
                _DeliverySlotGrid(
                  settings: widget.deliverySettings,
                  selectedValue: widget.selectedSlotValue,
                  onSelect: widget.onSlotSelected,
                ),
                const SizedBox(height: 24),

                // Price summary
                if (widget.cart.isNotEmpty) ...[
                  _PriceSummaryCard(
                    cart: widget.cart,
                    totalPrice: widget.totalPrice,
                  ),
                  const SizedBox(height: 20),
                ],

                // Confirm button
                _ConfirmButton(
                  enabled: widget.cart.isNotEmpty &&
                      widget.selectedSlotValue != null &&
                      !widget.submitting,
                  loading: widget.submitting,
                  onTap: widget.onSubmit,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CART ITEM TILE
// ─────────────────────────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  final _CartItem item;
  final VoidCallback onDelete;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartItemTile({
    required this.item,
    required this.onDelete,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = item.quantity < item.product.stock;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 44,
              color: Colors.white,
              child: (item.product.imageUrl ?? '').trim().isEmpty
                  ? const Icon(Icons.image_outlined, size: 20, color: AppColors.mutedText)
                  : Image.network(item.product.imageUrl!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),

          // Name + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '${item.effectivePrice.toStringAsFixed(0)} F × ${item.quantity} = ${item.total.toStringAsFixed(0)} F',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SmallQtyBtn(
                icon: Icons.remove_rounded,
                onTap: onDecrement,
                color: AppColors.mutedText,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
              ),
              _SmallQtyBtn(
                icon: Icons.add_rounded,
                onTap: canAdd ? onIncrement : null,
                color: canAdd ? AppColors.brandGreen : Colors.grey.shade300,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallQtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _SmallQtyBtn({required this.icon, this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY SLOT GRID
// ─────────────────────────────────────────────────────────────────────────────

class _DeliverySlotGrid extends StatelessWidget {
  final List<DeliverySettingModel> settings;
  final String? selectedValue;
  final ValueChanged<String?> onSelect;

  const _DeliverySlotGrid({
    required this.settings,
    required this.selectedValue,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final options = <Map<String, String>>[];
    final startDay = now.hour >= 22 ? 2 : 1;

    for (int i = startDay; i <= 7; i++) {
      final date = now.add(Duration(days: i));
      final dayIndex = date.weekday;
      final setting = settings.firstWhere(
        (s) => s.dayIndex == dayIndex,
        orElse: () => DeliverySettingModel(
          day: '',
          dayIndex: -1,
          timeSlots: [],
          isActive: false,
        ),
      );
      if (!setting.isActive) continue;
      final dateStr =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      for (final slot in setting.timeSlots) {
        options.add({
          'day': setting.day,
          'date': dateStr,
          'slot': slot,
          'value': '$dateStr|$slot',
        });
      }
    }

    if (options.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Aucun créneau disponible pour les 7 prochains jours.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final value = o['value']!;
        final isSelected = selectedValue == value;
        return GestureDetector(
          onTap: () => onSelect(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brandGreen
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.brandGreen
                    : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.brandGreen.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  o['day']!,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: isSelected ? Colors.white : AppColors.text,
                  ),
                ),
                Text(
                  o['date']!,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  o['slot']!,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: isSelected ? Colors.white : AppColors.brandGreenDark,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRICE SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PriceSummaryCard extends StatelessWidget {
  final List<_CartItem> cart;
  final double totalPrice;

  const _PriceSummaryCard({required this.cart, required this.totalPrice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          ...cart.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.product.name} ×${item.quantity}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.total.toStringAsFixed(0)} F',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'TOTAL',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Text(
                  '${totalPrice.toStringAsFixed(0)} F',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.brandGreenDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _ConfirmButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF55D80F), Color(0xFF1FAE3C)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: enabled ? null : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.brandGreen.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: enabled ? Colors.white : Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Confirmer la commande',
                      style: TextStyle(
                        color: enabled ? Colors.white : Colors.grey.shade400,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING CART BAR (MOBILE)
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingCartBar extends StatelessWidget {
  final int totalItems;
  final double totalPrice;
  final VoidCallback onTap;

  const _FloatingCartBar({
    required this.totalItems,
    required this.totalPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF55D80F), Color(0xFF1FAE3C)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandGreen.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '$totalItems',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Voir le panier & valider',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              '${totalPrice.toStringAsFixed(0)} F',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE CHECKOUT BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _MobileCheckoutSheet extends StatelessWidget {
  final List<_CartItem> cart;
  final List<DeliverySettingModel> deliverySettings;
  final TextEditingController addressCtrl;
  final String? selectedSlotValue;
  final bool submitting;
  final int totalItems;
  final double totalPrice;
  final ValueChanged<String?> onSlotSelected;
  final void Function(int idx) onDeleteItem;
  final void Function(_CartItem) onIncrement;
  final void Function(_CartItem) onDecrement;
  final VoidCallback onSubmit;

  const _MobileCheckoutSheet({
    required this.cart,
    required this.deliverySettings,
    required this.addressCtrl,
    required this.selectedSlotValue,
    required this.submitting,
    required this.totalItems,
    required this.totalPrice,
    required this.onSlotSelected,
    required this.onDeleteItem,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: AppColors.brandGreen),
                  const SizedBox(width: 8),
                  Text(
                    'Récapitulatif ($totalItems article${totalItems > 1 ? 's' : ''})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),

            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // Cart items
                  _SectionTitle(title: 'Articles', icon: Icons.list_alt_rounded),
                  const SizedBox(height: 8),
                  ...List.generate(cart.length, (i) {
                    final item = cart[i];
                    return _CartItemTile(
                      item: item,
                      onDelete: () => onDeleteItem(i),
                      onIncrement: () => onIncrement(item),
                      onDecrement: () => onDecrement(item),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Address
                  _SectionTitle(title: 'Adresse de livraison', icon: Icons.location_on_outlined),
                  const SizedBox(height: 8),
                  _StyledTextField(
                    controller: addressCtrl,
                    hint: 'Ex: Parcelles Assainies U24, Dakar',
                    prefixIcon: Icons.home_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Delivery slots
                  _SectionTitle(title: 'Créneau de livraison *', icon: Icons.schedule_outlined),
                  const SizedBox(height: 8),
                  _DeliverySlotGrid(
                    settings: deliverySettings,
                    selectedValue: selectedSlotValue,
                    onSelect: onSlotSelected,
                  ),
                  const SizedBox(height: 20),

                  // Price
                  _PriceSummaryCard(cart: cart, totalPrice: totalPrice),
                  const SizedBox(height: 20),

                  // Confirm
                  _ConfirmButton(
                    enabled: cart.isNotEmpty &&
                        selectedSlotValue != null &&
                        !submitting,
                    loading: submitting,
                    onTap: onSubmit,
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUCCESS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessDialog extends StatefulWidget {
  final int orderId;
  final String clientName;
  final double total;
  final int itemCount;
  final VoidCallback onDone;

  const _SuccessDialog({
    required this.orderId,
    required this.clientName,
    required this.total,
    required this.itemCount,
    required this.onDone,
  });

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated checkmark
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF55D80F), Color(0xFF1FAE3C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandGreen.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Commande créée !',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'La commande #${widget.orderId} a bien été enregistrée pour ${widget.clientName}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Details
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Commande n°',
                      value: '#${widget.orderId}',
                      valueColor: AppColors.brandGreenDark,
                    ),
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: 'Nombre d\'articles',
                      value: '${widget.itemCount}',
                    ),
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: 'Total',
                      value: '${widget.total.toStringAsFixed(0)} F CFA',
                      valueColor: AppColors.brandGreenDark,
                      isBold: true,
                    ),
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: 'Statut',
                      value: 'En attente',
                      valueColor: AppColors.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Done button
              GestureDetector(
                onTap: widget.onDone,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF55D80F), Color(0xFF1FAE3C)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandGreen.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Terminé',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: valueColor ?? AppColors.text,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS / SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brandGreenDark),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: AppColors.text,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.mutedText,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        prefixIcon: Icon(prefixIcon, size: 18, color: AppColors.mutedText),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.5),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Icon(Icons.search_rounded, color: AppColors.mutedText, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.text,
              ),
              decoration: const InputDecoration(
                hintText: 'Rechercher un produit...',
                hintStyle: TextStyle(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.close_rounded, size: 18, color: AppColors.mutedText),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.brandGreen : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.brandGreen : AppColors.border,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.brandGreen.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
