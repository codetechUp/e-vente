import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/promotion_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/categories_service.dart';
import '../../services/products_service.dart';
import '../../services/promotions_service.dart';
import '../../utils/constants/app_colors.dart';
import '../../utils/constants/app_sizes.dart';
import '../cart_view.dart';
import '../../widgets/badge_icon_button.dart';

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key});

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  final _categoriesService = CategoriesService();
  final _productsService = ProductsService();
  final _promotionsService = PromotionsService();
  final _searchController = TextEditingController();

  late Future<_CatalogData> _future;
  int? _selectedCategoryId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_CatalogData> _load() async {
    final results = await Future.wait([
      _productsService.getAll(),
      _promotionsService.getAll(),
    ]);
    final products = results[0] as List<ProductModel>;
    final promos = results[1] as List<PromotionModel>;

    List<CategoryModel> categories;
    try {
      categories = await _categoriesService.getAll();
    } catch (e) {
      debugPrint('[CatalogTab] Erreur chargement catégories: $e');
      categories = [];
    }

    final now = DateTime.now();
    final promoMap = <int, int>{};
    for (final p in promos) {
      if (!p.isActive) continue;
      if (p.endDate != null && p.endDate!.isBefore(now)) continue;
      if (p.productId != null && p.discountPercent != null) {
        promoMap[p.productId!] = p.discountPercent!;
      }
    }

    return _CatalogData(
      categories: categories,
      products: products,
      promoMap: promoMap,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.padding,
              10,
              AppSizes.padding,
              10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SearchBar(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    // TODO: Implement barcode scanner
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  color: AppColors.mutedText,
                  iconSize: 22,
                  tooltip: 'Scanner un code-barres',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                const SizedBox(width: 2),
                BadgeIconButton(
                  icon: Icons.shopping_cart_outlined,
                  badge: context.watch<CartProvider>().totalItems,
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => CartView()));
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<_CatalogData>(
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

                final data = snapshot.data;
                if (data == null) return const SizedBox.shrink();

                // Special value -1 for "En promo" filter
                const promoFilterId = -1;
                final isPromoFilter = _selectedCategoryId == promoFilterId;

                List<ProductModel> filtered;
                if (isPromoFilter) {
                  filtered = data.products
                      .where((p) => data.promoMap.containsKey(p.id))
                      .toList();
                } else if (_selectedCategoryId == null) {
                  filtered = data.products;
                } else {
                  filtered = data.products
                      .where((p) => p.categoryId == _selectedCategoryId)
                      .toList();
                }

                if (_searchQuery.isNotEmpty) {
                  filtered = filtered
                      .where((p) => p.name.toLowerCase().contains(_searchQuery))
                      .toList();
                }

                return Row(
                  children: [
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 110),
                        children: [
                          _CategoryChip(
                            icon: Icons.storefront,
                            label: 'Tout',
                            active: _selectedCategoryId == null,
                            onTap: () =>
                                setState(() => _selectedCategoryId = null),
                          ),
                          const SizedBox(height: 4),
                          _CategoryChip(
                            icon: Icons.local_fire_department,
                            label: 'En promo',
                            active: isPromoFilter,
                            onTap: () =>
                                setState(() => _selectedCategoryId = promoFilterId),
                          ),
                          const SizedBox(height: 6),
                          ...data.categories
                              .where((c) => c.id != null)
                              .map(
                                (c) => _CategoryChip(
                                  icon: _iconForCategory(c.name),
                                  label: c.name,
                                  active: _selectedCategoryId == c.id,
                                  onTap: () => setState(
                                    () => _selectedCategoryId = c.id,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(
                                0,
                                0,
                                AppSizes.padding,
                                110,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(
                                  AppSizes.paddingLg,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusLg,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 46,
                                      color: AppColors.mutedText,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Aucun produit',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ajoute des produits depuis Gestion > Produits',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.mutedText,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                0,
                                0,
                                AppSizes.padding,
                                110,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.65,
                                  ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final p = filtered[index];
                                final discountPct = data.promoMap[p.id];
                                return _CatalogProductCard(
                                  product: p,
                                  discountPercent: discountPct,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogData {
  final List<CategoryModel> categories;
  final List<ProductModel> products;
  final Map<int, int> promoMap;

  const _CatalogData({
    required this.categories,
    required this.products,
    required this.promoMap,
  });
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.mutedText, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Rechercher un produit',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              color: AppColors.mutedText,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            ),
        ],
      ),
    );
  }
}

IconData _iconForCategory(String name) {
  final lower = name.toLowerCase().trim();
  if (lower.contains('jus') || lower.contains('boite')) return Icons.water_drop;
  if (lower.contains('soda') || lower.contains('can')) return Icons.local_drink;
  if (lower.contains('café') || lower.contains('cafe') || lower.contains('thé') || lower.contains('the') || lower.contains('céréale') || lower.contains('cereale')) {
    return Icons.coffee;
  }
  if (lower.contains('cosmétique') || lower.contains('cosmetique')) return Icons.face;
  if (lower.contains('cuisine')) return Icons.cookie;
  if (lower.contains('biscuit') || lower.contains('gâteau') || lower.contains('gateau')) return Icons.bakery_dining;
  if (lower.contains('conserve')) return Icons.inventory_2;
  return Icons.category_outlined;
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _CategoryChip({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.accent : AppColors.border,
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? AppColors.accent : AppColors.mutedText,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: active ? AppColors.text : AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPrice(double price) {
  final parts = price.toStringAsFixed(0).split('');
  final buffer = StringBuffer();
  for (int i = 0; i < parts.length; i++) {
    if (i > 0 && (parts.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(parts[i]);
  }
  return buffer.toString();
}

class _CatalogProductCard extends StatelessWidget {
  final ProductModel product;
  final int? discountPercent;

  const _CatalogProductCard({
    required this.product,
    this.discountPercent,
  });

  @override
  Widget build(BuildContext context) {
    final hasPromo = discountPercent != null && discountPercent! > 0;
    final discountedPrice = hasPromo
        ? product.price * (1 - discountPercent! / 100)
        : product.price;

    final cart = context.watch<CartProvider>();
    final quantity = cart.items
        .where((item) => item.product.id == product.id)
        .fold<int>(0, (sum, item) => sum + item.quantity);

    // No points

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
          // Image section
          Expanded(
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (product.imageUrl ?? '').trim().isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 48,
                              color: AppColors.mutedText,
                            ),
                          )
                        : Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ),
                  ),
                ),
                if (hasPromo)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF3B30,
                            ).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '-$discountPercent%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Info section
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.3,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasPromo) ...[
                      Text(
                        '${_formatPrice(discountedPrice)} F',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatPrice(product.price)} F',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.mutedText,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                      ),
                    ] else
                      Text(
                        '${_formatPrice(product.price)} F',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Quantity counter
                Row(
                  children: [
                    if (quantity > 0) ...[
                      InkWell(
                        onTap: () => cart.decrement(product),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.remove,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    InkWell(
                      onTap: () {
                        cart.add(
                          product,
                          effectivePrice: hasPromo ? discountedPrice : null,
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
