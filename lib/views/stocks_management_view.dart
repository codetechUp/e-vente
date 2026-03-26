import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../models/stock_model.dart';
import '../services/products_service.dart';
import '../services/stocks_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';

class StocksManagementView extends StatefulWidget {
  const StocksManagementView({super.key});

  @override
  State<StocksManagementView> createState() => _StocksManagementViewState();
}

class _StocksManagementViewState extends State<StocksManagementView> {
  final _stocksService = StocksService();
  final _productsService = ProductsService();

  late Future<_StocksData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StocksData> _load() async {
    final results = await Future.wait([
      _productsService.getAll(),
      _stocksService.getAll(),
    ]);
    final products = results[0] as List<ProductModel>;
    final stocks = results[1] as List<StockModel>;

    final stockByProduct = <int, StockModel>{};
    for (final s in stocks) {
      if (s.productId != null) {
        stockByProduct[s.productId!] = s;
      }
    }

    return _StocksData(products: products, stockByProduct: stockByProduct);
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _editStock(ProductModel product, StockModel? stock) async {
    final productId = product.id;
    if (productId == null) return;

    final controller = TextEditingController(text: '${stock?.quantity ?? 0}');

    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stock: ${product.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Quantité',
            hintText: 'Ex: 50',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, qty);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      if (stock != null && stock.id != null) {
        await _stocksService.updateById(stock.id!, {
          'quantity': result,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _stocksService.create(
          StockModel(productId: productId, quantity: result),
        );
      }
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock mis à jour')));
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
        title: const Text('Gestion des stocks'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<_StocksData>(
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
          if (data == null || data.products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 58,
                      color: AppColors.mutedText,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Aucun produit',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.padding,
              12,
              AppSizes.padding,
              24,
            ),
            itemCount: data.products.length,
            itemBuilder: (context, index) {
              final p = data.products[index];
              final stock = p.id != null ? data.stockByProduct[p.id!] : null;
              final qty = stock?.quantity ?? 0;
              final isLow = qty > 0 && qty <= 5;
              final isOut = qty == 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(AppSizes.padding),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(
                    color: isOut
                        ? AppColors.danger.withValues(alpha: 0.5)
                        : isLow
                        ? Colors.orange.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radius),
                      child: Container(
                        width: 50,
                        height: 50,
                        color: AppColors.background,
                        child: (p.imageUrl ?? '').trim().isEmpty
                            ? const Icon(
                                Icons.image_outlined,
                                color: AppColors.mutedText,
                              )
                            : Image.network(
                                p.imageUrl!,
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
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? AppColors.danger.withValues(alpha: 0.12)
                                      : isLow
                                      ? Colors.orange.withValues(alpha: 0.12)
                                      : AppColors.success.withValues(
                                          alpha: 0.12,
                                        ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  isOut
                                      ? 'Rupture'
                                      : isLow
                                      ? 'Stock faible: $qty'
                                      : 'En stock: $qty',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: isOut
                                            ? AppColors.danger
                                            : isLow
                                            ? Colors.orange
                                            : AppColors.success,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editStock(p, stock),
                      icon: const Icon(Icons.edit_outlined),
                      color: AppColors.mutedText,
                      tooltip: 'Modifier le stock',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StocksData {
  final List<ProductModel> products;
  final Map<int, StockModel> stockByProduct;

  const _StocksData({required this.products, required this.stockByProduct});
}
