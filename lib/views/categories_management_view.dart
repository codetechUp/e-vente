import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../services/categories_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class CategoriesManagementView extends StatefulWidget {
  const CategoriesManagementView({super.key});

  @override
  State<CategoriesManagementView> createState() => _CategoriesManagementViewState();
}

class _CategoriesManagementViewState extends State<CategoriesManagementView> {
  final _service = CategoriesService();

  late Future<List<CategoryModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAll();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.getAll();
    });
  }

  Future<void> _showCreate() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(
        title: 'Ajouter une catégorie',
        primaryCta: 'Ajouter',
        initialName: '',
        initialDescription: '',
        onSubmit: (name, description) async {
          await _service.create(
            CategoryModel(
              name: name,
              description: description.isEmpty ? null : description,
            ),
          );
        },
      ),
    );

    if (ok == true) {
      await _reload();
    }
  }

  Future<void> _showEdit(CategoryModel category) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(
        title: 'Modifier catégorie',
        primaryCta: 'Enregistrer',
        initialName: category.name,
        initialDescription: category.description ?? '',
        onSubmit: (name, description) async {
          if (category.id == null) return;
          await _service.updateById(category.id!, {
            'name': name,
            'description': description.isEmpty ? null : description,
          });
        },
      ),
    );

    if (ok == true) {
      await _reload();
    }
  }

  Future<void> _delete(CategoryModel category) async {
    if (category.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer "${category.name}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.deleteById(category.id!);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreate,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<CategoryModel>>(
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

          final items = snapshot.data ?? const <CategoryModel>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.padding,
              12,
              AppSizes.padding,
              110,
            ),
            children: [
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
                            'Liste',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${items.length} catégorie(s)',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: AppButton(label: 'Ajouter', onPressed: _showCreate),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...items.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CategoryTile(
                    category: c,
                    onEdit: () => _showEdit(c),
                    onDelete: () => _delete(c),
                  ),
                ),
              ),
              if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingLg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.category_outlined, size: 48, color: AppColors.mutedText),
                      const SizedBox(height: 10),
                      Text(
                        'Aucune catégorie',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ajoute une catégorie pour organiser le catalogue.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.mutedText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 14),
                      AppButton(label: 'Ajouter', onPressed: _showCreate),
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

class _CategoryTile extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
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
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.category_outlined, color: AppColors.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if ((category.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    category.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.mutedText,
            tooltip: 'Modifier',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.danger,
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  final String title;
  final String primaryCta;
  final String initialName;
  final String initialDescription;
  final Future<void> Function(String name, String description) onSubmit;

  const _CategorySheet({
    required this.title,
    required this.primaryCta,
    required this.initialName,
    required this.initialDescription,
    required this.onSubmit,
  });

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _description = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _nameValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Nom obligatoire';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      await widget.onSubmit(_name.text.trim(), _description.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSizes.padding,
        right: AppSizes.padding,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _name,
                label: 'Nom',
                hint: 'Ex: Boissons',
                validator: _nameValidator,
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _description,
                label: 'Description',
                hint: 'Optionnel',
                prefixIcon: const Icon(Icons.notes_outlined),
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
    );
  }
}
