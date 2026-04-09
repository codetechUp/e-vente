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
      _categoriesService.getAll(),
      _productsService.getAll(),
      _promotionsService.getAll(),
    ]);
    final categories = results[0] as List<CategoryModel>;
    final products = results[1] as List<ProductModel>;
    final promos = results[2] as List<PromotionModel>;

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
                const SizedBox(width: 10),
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

                var filtered = _selectedCategoryId == null
                    ? data.products
                    : data.products
                          .where((p) => p.categoryId == _selectedCategoryId)
                          .toList();

                if (_searchQuery.isNotEmpty) {
                  filtered = filtered
                      .where((p) => p.name.toLowerCase().contains(_searchQuery))
                      .toList();
                }

                return Row(
                  children: [
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 92,
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
                          const SizedBox(height: 6),
                          ...data.categories
                              .where((c) => c.id != null)
                              .map(
                                (c) => _CategoryChip(
                                  icon: Icons.category_outlined,
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
                                    childAspectRatio: 0.72,
                                  ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final p = filtered[index];
                                final discountPct = data.promoMap[p.id];
                                return _CatalogProductCard(
                                  product: p,
                                  discountPercent: discountPct,
                                  onAdd: () {
                                    double? effectivePrice;
                                    if (discountPct != null) {
                                      effectivePrice =
                                          p.price * (1 - discountPct / 100);
                                    }
                                    context.read<CartProvider>().add(
                                      p,
                                      effectivePrice: effectivePrice,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Ajouté au panier'),
                                      ),
                                    );
                                  },
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
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(
              color: active ? AppColors.accent : AppColors.border,
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: active ? AppColors.accent : AppColors.mutedText,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
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

class _CatalogProductCard extends StatelessWidget {
  final ProductModel product;
  final int? discountPercent;
  final VoidCallback onAdd;

  const _CatalogProductCard({
    required this.product,
    required this.onAdd,
    this.discountPercent,
  });

  @override
  Widget build(BuildContext context) {
    final hasPromo = discountPercent != null && discountPercent! > 0;
    final discountedPrice = hasPromo
        ? product.price * (1 - discountPercent! / 100)
        : product.price;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
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
                    top: 14,
                    left: 14,
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
                Positioned(
                  bottom: 14,
                  right: 14,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onAdd,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF55D80F), Color(0xFF1FAE3C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF55D80F,
                              ).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (hasPromo) ...[
                      Text(
                        '${discountedPrice.toStringAsFixed(0)} F',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${product.price.toStringAsFixed(0)} F',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else
                      Text(
                        '${product.price.toStringAsFixed(0)} F',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w900,
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
