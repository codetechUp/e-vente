import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../models/stock_entry_model.dart';
import '../services/products_service.dart';
import '../services/stock_entries_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class StockEntryView extends StatefulWidget {
  const StockEntryView({super.key});

  @override
  State<StockEntryView> createState() => _StockEntryViewState();
}

class _StockEntryViewState extends State<StockEntryView> {
  final _stockEntriesService = StockEntriesService();
  final _productsService = ProductsService();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = false;
  List<ProductModel> _products = [];
  int? _selectedProductId;
  String _selectedEntryType = 'purchase';

  final _entryTypes = const [
    {'value': 'purchase', 'label': 'Achat', 'icon': Icons.shopping_cart},
    {'value': 'adjustment', 'label': 'Ajustement', 'icon': Icons.tune},
    {'value': 'return', 'label': 'Retour', 'icon': Icons.keyboard_return},
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productsService.getAll();
      if (!mounted) return;
      setState(() {
        _products = products;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _save() async {
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un produit')),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une quantité valide')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Créer l'entrée de stock
      await _stockEntriesService.create(
        StockEntryModel(
          productId: _selectedProductId!,
          quantity: quantity,
          entryType: _selectedEntryType,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          createdBy:
              null, // Ne pas envoyer created_by pour éviter l'erreur de clé étrangère
        ),
      );

      // Mettre à jour le stock du produit
      final product = _products.firstWhere((p) => p.id == _selectedProductId);
      final newStock = product.stock + quantity;
      await _productsService.updateById(_selectedProductId!, {
        'stock': newStock,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrée de stock enregistrée avec succès'),
        ),
      );
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Nouvelle entrée de stock',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.padding),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF55D80F), Color(0xFF1FAE3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF55D80F).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestion des stocks',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enregistrez vos entrées de stock',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 1.5),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Informations de l\'entrée',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Type d\'entrée',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: _entryTypes.map((type) {
                    final isSelected = _selectedEntryType == type['value'];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedEntryType = type['value'] as String;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF55D80F)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF55D80F)
                                    : AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  type['icon'] as IconData,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.mutedText,
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  type['label'] as String,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.text,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Produit',
                    prefixIcon: const Icon(Icons.shopping_bag_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedProductId,
                      isExpanded: true,
                      isDense: true,
                      hint: const Text('Sélectionner un produit'),
                      items: _products.map((product) {
                        return DropdownMenuItem<int>(
                          value: product.id,
                          child: Text(product.name),
                        );
                      }).toList(),
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() {
                                _selectedProductId = value;
                              });
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _quantityController,
                  label: 'Quantité',
                  hint: 'Ex: 100',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.numbers),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _notesController,
                  label: 'Notes (optionnel)',
                  hint: 'Ajouter des notes...',
                  prefixIcon: const Icon(Icons.note_outlined),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Enregistrer l\'entrée',
                  loading: _loading,
                  onPressed: _loading ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
