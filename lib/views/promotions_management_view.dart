import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../models/promotion_model.dart';
import '../services/products_service.dart';
import '../services/promotions_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';

class PromotionsManagementView extends StatefulWidget {
  const PromotionsManagementView({super.key});

  @override
  State<PromotionsManagementView> createState() =>
      _PromotionsManagementViewState();
}

class _PromotionsManagementViewState extends State<PromotionsManagementView> {
  final _promotionsService = PromotionsService();
  final _productsService = ProductsService();

  List<PromotionModel> _promotions = [];
  List<ProductModel> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _promotionsService.getAll(),
        _productsService.getAll(),
      ]);
      _promotions = results[0] as List<PromotionModel>;
      _products = results[1] as List<ProductModel>;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _productName(int? productId) {
    if (productId == null) return '-';
    final p = _products.where((p) => p.id == productId).firstOrNull;
    return p?.name ?? 'Produit #$productId';
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _add() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PromotionSheet(
        products: _products,
        onSubmit: (promo) async {
          await _promotionsService.create(promo);
        },
      ),
    );
    if (result == true) await _load();
  }

  Future<void> _edit(PromotionModel promo) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PromotionSheet(
        products: _products,
        initial: promo,
        onSubmit: (updated) async {
          final id = promo.id;
          if (id == null) return;
          await _promotionsService.updateById(id, updated.toJson());
        },
      ),
    );
    if (result == true) await _load();
  }

  Future<void> _delete(PromotionModel promo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la promotion ?'),
        content: Text('Produit: ${_productName(promo.productId)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = promo.id;
    if (id == null) return;
    try {
      await _promotionsService.deleteById(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _toggleActive(PromotionModel promo) async {
    final id = promo.id;
    if (id == null) return;
    try {
      await _promotionsService.updateById(id, {'is_active': !promo.isActive});
      await _load();
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Promotions',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _add,
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _promotions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_offer_outlined,
                      size: 58,
                      color: AppColors.mutedText,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Aucune promotion',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.padding,
                  10,
                  AppSizes.padding,
                  110,
                ),
                itemCount: _promotions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final promo = _promotions[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: promo.isActive
                                ? AppColors.accent.withValues(alpha: 0.18)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              '-${promo.discountPercent ?? 0}%',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: promo.isActive
                                        ? Colors.black
                                        : AppColors.mutedText,
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
                                _productName(promo.productId),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_formatDate(promo.startDate)} → ${_formatDate(promo.endDate)}',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: AppColors.mutedText,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: promo.isActive,
                          activeTrackColor: AppColors.accent,
                          onChanged: (_) => _toggleActive(promo),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _edit(promo);
                            if (v == 'delete') _delete(promo);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Modifier'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Supprimer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _PromotionSheet extends StatefulWidget {
  final List<ProductModel> products;
  final PromotionModel? initial;
  final Future<void> Function(PromotionModel promo) onSubmit;

  const _PromotionSheet({
    required this.products,
    this.initial,
    required this.onSubmit,
  });

  @override
  State<_PromotionSheet> createState() => _PromotionSheetState();
}

class _PromotionSheetState extends State<_PromotionSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _discount;
  ProductModel? _selectedProduct;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _discount = TextEditingController(
      text: initial?.discountPercent?.toString() ?? '',
    );
    _isActive = initial?.isActive ?? true;
    _startDate = initial?.startDate;
    _endDate = initial?.endDate;

    if (initial?.productId != null) {
      _selectedProduct = widget.products
          .where((p) => p.id == initial!.productId)
          .firstOrNull;
    }
  }

  @override
  void dispose() {
    _discount.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Choisir';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sélectionne un produit.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final promo = PromotionModel(
        productId: _selectedProduct!.id,
        discountPercent: int.tryParse(_discount.text.trim()) ?? 0,
        startDate: _startDate,
        endDate: _endDate,
        isActive: _isActive,
      );
      await widget.onSubmit(promo);
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
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLg),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingLg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.initial == null
                    ? 'Nouvelle promotion'
                    : 'Modifier promotion',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ProductModel>(
                initialValue: _selectedProduct,
                decoration: const InputDecoration(labelText: 'Produit'),
                items: widget.products
                    .where((p) => p.id != null)
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedProduct = v),
                validator: (v) => v == null ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discount,
                decoration: const InputDecoration(
                  labelText: 'Réduction (%)',
                  hintText: 'Ex: 20',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Obligatoire';
                  final n = int.tryParse(s);
                  if (n == null || n < 1 || n > 100) {
                    return 'Entre 1 et 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isStart: true),
                      child: Text('Début: ${_fmtDate(_startDate)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isStart: false),
                      child: Text('Fin: ${_fmtDate(_endDate)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                activeTrackColor: AppColors.accent,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: AppSizes.buttonHeight,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.initial == null ? 'Créer' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
