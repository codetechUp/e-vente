import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/promotion_model.dart';
import '../services/categories_service.dart';
import '../services/products_service.dart';
import '../services/promotions_service.dart';
import '../services/storage_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import 'notifications_management_view.dart';

// (Removed statistic models)

// ─────────────────────────────────────────────────────────────────────────────
// MAIN VIEW
// ─────────────────────────────────────────────────────────────────────────────

class ProductsManagementView extends StatefulWidget {
  const ProductsManagementView({super.key});

  @override
  State<ProductsManagementView> createState() => _ProductsManagementViewState();
}

class _ProductsManagementViewState extends State<ProductsManagementView> {
  final _productsService = ProductsService();
  final _categoriesService = CategoriesService();

  late Future<_ProductsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProductsData> _load() async {
    final categories = await _categoriesService.getAll();
    final products = await _productsService.getAll();
    
    // Sort products by priority (grille) and name
    products.sort((a, b) {
      int priority(String? value) {
        switch ((value ?? '').trim().toLowerCase()) {
          case '1':
          case 'premium':
          case 'vedette':
            return 0;
          case '2':
          case 'silver':
          case 'promo':
            return 1;
          case '3':
          case 'gold':
          case 'retour_stock':
            return 2;
          default:
            return 3;
        }
      }

      final grilleCompare = priority(a.grille).compareTo(priority(b.grille));
      if (grilleCompare != 0) return grilleCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return _ProductsData(
      categories: categories, 
      products: products, 
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _showCreate(List<CategoryModel> categories) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductSheet(
        title: 'Ajouter un produit',
        primaryCta: 'Ajouter',
        categories: categories,
        initial: null,
        onSubmit: (payload) async {
          return await _productsService.create(payload);
        },
      ),
    );

    if (ok == true) {
      await _reload();
    }
  }

  Future<void> _showEdit(
    ProductModel product,
    List<CategoryModel> categories,
  ) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductSheet(
        title: 'Modifier produit',
        primaryCta: 'Enregistrer',
        categories: categories,
        initial: product,
        onSubmit: (payload) async {
          if (product.id == null) return null;
          return await _productsService.updateById(product.id!, {
            'name': payload.name,
            'description': payload.description,
            'price': payload.price,
            'purchase_price': payload.purchasePrice,
            'grille': payload.grille,
            'category_id': payload.categoryId,
            'image_url': payload.imageUrl,
            'display': payload.display,
          });
        },
      ),
    );

    if (ok == true) {
      await _reload();
    }
  }

  Future<void> _delete(ProductModel product) async {
    if (product.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer "${product.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _productsService.deleteById(product.id!);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits & Analyses'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<_ProductsData>(
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

          final categoryById = <int, CategoryModel>{
            for (final c in data.categories)
              if (c.id != null) c.id!: c,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.padding,
              12,
              AppSizes.padding,
              110,
            ),
            children: [
              // ─── PRODUCTS LIST HEADER ───
              Container(
                padding: const EdgeInsets.all(AppSizes.padding),
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
                            'Catalogue Produits',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${data.products.length} produit(s)',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: AppButton(
                        label: 'Ajouter',
                        onPressed: () => _showCreate(data.categories),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ─── PRODUCTS TILES ───
              ...data.products.map((p) {
                final categoryName = p.categoryId == null
                    ? 'Sans catégorie'
                    : (categoryById[p.categoryId!]?.name ??
                          'Catégorie #${p.categoryId}');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ProductTile(
                    product: p,
                    categoryName: categoryName,
                    onEdit: () => _showEdit(p, data.categories),
                    onDelete: () => _delete(p),
                    onNotify: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificationsManagementView(
                            initialProduct: p,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
              if (data.products.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingLg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: AppColors.mutedText,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Aucun produit',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ajoute des produits avec image pour alimenter le catalogue.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'Ajouter',
                        onPressed: () => _showCreate(data.categories),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductsData {
  final List<CategoryModel> categories;
  final List<ProductModel> products;

  const _ProductsData({
    required this.categories,
    required this.products,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT TILE
// ─────────────────────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final ProductModel product;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onNotify;

  const _ProductTile({
    required this.product,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
    this.onNotify,
  });

  @override
  Widget build(BuildContext context) {
    final grille = (product.grille ?? '').trim().toLowerCase();
    String? grilleLabel;
    Color? grilleColor;
    if (grille == '1' || grille == 'premium' || grille == 'vedette') {
      grilleLabel = 'Produit vedette';
      grilleColor = const Color(0xFF6C4DFF);
    } else if (grille == '2' || grille == 'silver' || grille == 'promo') {
      grilleLabel = 'En promotion';
      grilleColor = const Color(0xFFFF6B6B);
    } else if (grille == '3' || grille == 'gold' || grille == 'retour_stock') {
      grilleLabel = 'Retour en stock';
      grilleColor = const Color(0xFF4FACFE);
    }

    final profit = product.price - product.purchasePrice;
    final margin = product.price > 0 ? (profit / product.price) * 100 : 0.0;
    final potentialProfit = profit * product.stock;

    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 58,
              height: 58,
              color: AppColors.background,
              child: (product.imageUrl ?? '').trim().isEmpty
                  ? const Icon(Icons.image_outlined, color: AppColors.mutedText)
                  : Image.network(
                      product.imageUrl!,
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
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  categoryName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (grilleLabel != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: grilleColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      grilleLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: product.display
                            ? const Color(0xFF55D80F).withValues(alpha: 0.1)
                            : AppColors.mutedText.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            product.display
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 11,
                            color: product.display
                                ? const Color(0xFF55D80F)
                                : AppColors.mutedText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product.display ? 'Affiché' : 'Masqué',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: product.display
                                  ? const Color(0xFF55D80F)
                                  : AppColors.mutedText,
                              fontWeight: FontWeight.w900,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: product.stock > 0
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 11,
                            color: product.stock > 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Stock: ${product.stock}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: product.stock > 0
                                      ? AppColors.success
                                      : AppColors.danger,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Prices details
                Row(
                  children: [
                    Text(
                      'Vente: ${product.price.toStringAsFixed(0)} F',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Achat: ${product.purchasePrice.toStringAsFixed(0)} F',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Profit margin and profit potential details
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: profit >= 0 
                            ? const Color(0xFF55D80F).withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Marge: ${margin.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: profit >= 0 ? const Color(0xFF55D80F) : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Profit U: ${profit.toStringAsFixed(0)} F',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: profit >= 0 ? const Color(0xFF3B82F6) : Colors.red,
                      ),
                    ),
                    if (product.stock > 0 && profit > 0) ...[
                      const SizedBox(width: 10),
                      Text(
                        'Potentiel: ${potentialProfit.toStringAsFixed(0)} F',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                color: AppColors.mutedText,
                tooltip: 'Modifier',
              ),
              if (product.stock > 0 && onNotify != null)
                IconButton(
                  onPressed: onNotify,
                  icon: const Icon(Icons.notifications_active_outlined),
                  color: AppColors.brandGreen,
                  tooltip: 'Notifier',
                ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: AppColors.danger,
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE OR EDIT DIALOG SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ProductSheet extends StatefulWidget {
  final String title;
  final String primaryCta;
  final List<CategoryModel> categories;
  final ProductModel? initial;
  final Future<ProductModel?> Function(ProductModel payload) onSubmit;

  const _ProductSheet({
    required this.title,
    required this.primaryCta,
    required this.categories,
    required this.initial,
    required this.onSubmit,
  });

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _discount;

  CategoryModel? _category;
  String? _grille;
  XFile? _pickedImage;
  String? _imageUrl;
  bool _display = true;

  bool _loading = false;

  final _picker = ImagePicker();
  final _storage = StorageService();
  final _promotionsService = PromotionsService();
  PromotionModel? _existingPromo;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _description = TextEditingController(
      text: widget.initial?.description ?? '',
    );
    _price = TextEditingController(
      text: widget.initial == null ? '' : widget.initial!.price.toString(),
    );
    _purchasePrice = TextEditingController(
      text: widget.initial == null ? '' : widget.initial!.purchasePrice.toString(),
    );
    _discount = TextEditingController();

    _imageUrl = widget.initial?.imageUrl;
    _grille = widget.initial?.grille;

    // Normalize old grid data values for internal sheet selection
    if (_grille != null) {
      final g = _grille!.toLowerCase().trim();
      if (g == 'premium' || g == '1' || g == 'vedette') {
        _grille = '1';
      } else if (g == 'silver' || g == '2' || g == 'promo') {
        _grille = '2';
      } else if (g == 'gold' || g == '3' || g == 'retour_stock') {
        _grille = '3';
      } else {
        _grille = null;
      }
    }

    _display = widget.initial?.display ?? true;

    _category = widget.categories.firstWhere(
      (c) => c.id != null && c.id == widget.initial?.categoryId,
      orElse: () => widget.categories.isEmpty
          ? const CategoryModel(name: '')
          : widget.categories.first,
    );
    if (_category?.id == null) {
      _category = null;
    }
    _loadPromotion();
  }

  Future<void> _loadPromotion() async {
    if (widget.initial?.id == null) return;
    try {
      final promos = await _promotionsService.getAll();
      final promo = promos.firstWhere(
        (p) => p.productId == widget.initial!.id && p.isActive,
        orElse: () => const PromotionModel(),
      );
      if (promo.id != null) {
        setState(() {
          _existingPromo = promo;
          _discount.text = promo.discountPercent?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading promo: $e');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _purchasePrice.dispose();
    _discount.dispose();
    super.dispose();
  }

  String? _nameValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Nom obligatoire';
    return null;
  }

  String? _priceValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Prix obligatoire';
    final p = double.tryParse(v.replaceAll(',', '.'));
    if (p == null || p < 0) return 'Prix invalide';
    return null;
  }

  String? _purchasePriceValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Prix d\'achat obligatoire';
    final p = double.tryParse(v.replaceAll(',', '.'));
    if (p == null || p < 0) return 'Prix invalide';
    return null;
  }

  String? _discountValidator(String? value) {
    if (_grille != 'promo') return null;
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Pourcentage obligatoire';
    final p = int.tryParse(v);
    if (p == null || p < 1 || p > 99) return 'Entre 1 et 99%';
    return null;
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      _pickedImage = file;
    });
  }

  Future<String?> _uploadIfNeeded() async {
    if (_pickedImage == null) return _imageUrl;
    final url = await _storage.uploadProductImage(file: _pickedImage!);
    return url;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      final uploadedUrl = await _uploadIfNeeded();

      final price = double.parse(_price.text.trim().replaceAll(',', '.'));
      final purchasePrice = double.parse(_purchasePrice.text.trim().replaceAll(',', '.'));

      final payload = ProductModel(
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        price: price,
        purchasePrice: purchasePrice,
        grille: _grille,
        categoryId: _category?.id,
        imageUrl: uploadedUrl,
        display: _display,
      );

      final createdOrUpdated = await widget.onSubmit(payload);
      final productId = createdOrUpdated?.id ?? widget.initial?.id;

      // Handle Promotion
      if (_grille == '2') {
        final disc = int.parse(_discount.text.trim());
        if (_existingPromo != null) {
          await _promotionsService.updateById(_existingPromo!.id!, {
            'discount_percent': disc,
            'is_active': true,
          });
        } else if (productId != null) {
          await _promotionsService.create(PromotionModel(
            productId: productId,
            discountPercent: disc,
            isActive: true,
          ));
        }
      } else if (_existingPromo != null) {
        // Disabled promotion since it is no longer en promotion
        await _promotionsService.updateById(_existingPromo!.id!, {
          'is_active': false,
        });
      }

      if (!mounted) return;
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
    final preview = _pickedImage != null
        ? Image.file(File(_pickedImage!.path), fit: BoxFit.cover)
        : ((_imageUrl ?? '').trim().isNotEmpty
              ? Image.network(
                  _imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.mutedText,
                  ),
                )
              : const Icon(Icons.image_outlined, color: AppColors.mutedText));

    return Container(
      padding: EdgeInsets.only(
        left: AppSizes.padding,
        right: AppSizes.padding,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _loading ? null : _pickImage,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      child: Stack(
                        children: [
                          Positioned.fill(child: Center(child: preview)),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.photo_library_outlined,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Choisir',
                                    style: Theme.of(context).textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _name,
                  label: 'Nom du produit',
                  hint: 'Ex: Huile 5L',
                  validator: _nameValidator,
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _price,
                        label: 'Taux de Vente (Client)',
                        hint: 'Ex: 21500',
                        keyboardType: TextInputType.number,
                        validator: _priceValidator,
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTextField(
                        controller: _purchasePrice,
                        label: 'Taux d\'Achat (Coût)',
                        hint: 'Ex: 17500',
                        keyboardType: TextInputType.number,
                        validator: _purchasePriceValidator,
                        prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _description,
                  label: 'Description',
                  hint: 'Optionnel',
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CategoryModel>(
                      value: _category,
                      isExpanded: true,
                      hint: const Text('Choisir une catégorie'),
                      items: widget.categories
                          .where((c) => c.id != null)
                          .map(
                            (c) =>
                                DropdownMenuItem(value: c, child: Text(c.name)),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _category = value),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _grille,
                      isExpanded: true,
                      hint: const Text('Choisir une grille de mise en avant'),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Aucune'),
                        ),
                        DropdownMenuItem<String?>(
                          value: '1',
                          child: Text('Produit vedette'),
                        ),
                        DropdownMenuItem<String?>(
                          value: '2',
                          child: Text('En promotion'),
                        ),
                        DropdownMenuItem<String?>(
                          value: '3',
                          child: Text('Retour en stock'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _grille = value),
                    ),
                  ),
                ),
                if (_grille == '2') ...[
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _discount,
                    label: 'Remise (%)',
                    hint: 'Ex: 20',
                    keyboardType: TextInputType.number,
                    validator: _discountValidator,
                    prefixIcon: const Icon(Icons.percent),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Afficher sur Découvrir',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Switch(
                        value: _display,
                        onChanged: (value) => setState(() => _display = value),
                        activeColor: const Color(0xFF55D80F),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: widget.primaryCta,
                  loading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
