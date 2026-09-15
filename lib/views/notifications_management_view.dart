import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';

class NotificationsManagementView extends StatefulWidget {
  final ProductModel? initialProduct;

  const NotificationsManagementView({super.key, this.initialProduct});

  @override
  State<NotificationsManagementView> createState() =>
      _NotificationsManagementViewState();
}

class _NotificationsManagementViewState
    extends State<NotificationsManagementView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String _selectedType = 'general'; // 'general', 'promo', 'restock'
  ProductModel? _selectedProduct;
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoadingProducts = false;
  bool _isSending = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      _selectedProduct = widget.initialProduct;
      final grille = (_selectedProduct!.grille ?? '').trim().toLowerCase();
      if (grille == '2' || grille == 'silver' || grille == 'promo') {
        _selectedType = 'promo';
      } else {
        _selectedType = 'restock';
      }
      _applyTemplate();
    }
    _fetchProducts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .order('name');
      final list = (response as List)
          .map((json) => ProductModel.fromJson(json))
          .toList();
      setState(() {
        _allProducts = list;
        _filteredProducts = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des produits : $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts
            .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _applyTemplate() {
    if (_selectedProduct == null) return;

    if (_selectedType == 'promo') {
      _titleController.text = '🔥 Super Promo : ${_selectedProduct!.name} !';
      _messageController.text =
          'Profitez d\'une offre exceptionnelle sur "${_selectedProduct!.name}" dès maintenant ! Commandez vite dans l\'application.';
      if (_selectedProduct!.imageUrl != null) {
        _imageUrlController.text = _selectedProduct!.imageUrl!;
      }
    } else if (_selectedType == 'restock') {
      _titleController.text = '⚡ Retour en Stock : ${_selectedProduct!.name} !';
      _messageController.text =
          'Le produit "${_selectedProduct!.name}" est de nouveau disponible ! Faites-vous livrer chez vous avant la rupture de stock.';
      if (_selectedProduct!.imageUrl != null) {
        _imageUrlController.text = _selectedProduct!.imageUrl!;
      }
    }
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
    });

    final title = _titleController.text.trim();
    final body = _messageController.text.trim();
    final imageUrl = _imageUrlController.text.trim();

    try {
      final supabase = Supabase.instance.client;

      // 1. Essayer d'enregistrer dans la table 'notifications' pour l'historique
      try {
        await supabase.from('notifications').insert({
          'title': title,
          'body': body,
          'type': _selectedType,
          'product_id': _selectedProduct?.id,
          'image_url': imageUrl.isNotEmpty ? imageUrl : null,
        });
      } catch (dbError) {
        // Optionnel : s'il n'y a pas de table 'notifications' configurée, on continue l'envoi du push
        debugPrint('[NotificationService] Erreur lors de l\'enregistrement en base de données : $dbError');
      }

      // 2. Déclencher l'envoi de la push notification via l'Edge Function
      await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'title': title,
          'body': body,
          'type': _selectedType,
          'productId': _selectedProduct?.id,
          'imageUrl': imageUrl.isNotEmpty ? imageUrl : null,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Notification envoyée avec succès à tous les utilisateurs !'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de l\'envoi de la notification push : $e'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Gestion des Notifications',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Glassmorphic App Logo Card
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/logo_padded.png',
                        height: 80,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.notifications_active_rounded,
                            size: 80,
                            color: AppColors.brandGreen,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Envoyer une Notification Push',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Diffusez des informations en temps réel à l\'ensemble des clients.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Form Segment title
                const Text(
                  'Configuration de la diffusion',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),

                // Notification Type Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type de Notification',
                    prefixIcon: Icon(Icons.merge_type_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'general',
                      child: Text('Notification Générale'),
                    ),
                    DropdownMenuItem(
                      value: 'promo',
                      child: Text('Promotion de Produit'),
                    ),
                    DropdownMenuItem(
                      value: 'restock',
                      child: Text('Retour de Stock'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedType = val;
                        if (_selectedType == 'general') {
                          _selectedProduct = null;
                        } else {
                          _applyTemplate();
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Product Selection Section
                if (_selectedType != 'general') ...[
                  const Text(
                    'Associer un Produit',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedProduct != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen.withValues(alpha: 0.08),
                        border: Border.all(color: AppColors.brandGreen, width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          if (_selectedProduct!.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _selectedProduct!.imageUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 48,
                                  height: 48,
                                  color: AppColors.border,
                                  child: const Icon(Icons.image),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.image),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedProduct!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${_selectedProduct!.price.toStringAsFixed(0)} F CFA',
                                  style: const TextStyle(
                                    color: AppColors.brandGreenDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                            onPressed: () {
                              setState(() {
                                _selectedProduct = null;
                                _titleController.clear();
                                _messageController.clear();
                                _imageUrlController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Search Bar for Product
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher un produit...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onChanged: _filterProducts,
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingProducts)
                      const Center(child: CircularProgressIndicator())
                    else
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _filteredProducts.isEmpty
                            ? const Center(child: Text('Aucun produit trouvé'))
                            : ListView.builder(
                                itemCount: _filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final p = _filteredProducts[index];
                                  return ListTile(
                                    leading: p.imageUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(
                                              p.imageUrl!,
                                              width: 36,
                                              height: 36,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.image),
                                            ),
                                          )
                                        : const Icon(Icons.image),
                                    title: Text(
                                      p.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: Text('${p.price.toStringAsFixed(0)} F CFA'),
                                    onTap: () {
                                      setState(() {
                                        _selectedProduct = p;
                                        _applyTemplate();
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                  ],
                  const SizedBox(height: 16),
                ],

                // Title Input
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre de la notification',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Veuillez saisir un titre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Message Body Input
                TextFormField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Contenu du message',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 50.0),
                      child: Icon(Icons.message_rounded),
                    ),
                    alignLabelWithHint: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Veuillez saisir un message';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Optional Image URL Input
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'URL de l\'image (optionnelle)',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSending ? null : _sendNotification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shadowColor: AppColors.brandGreen.withValues(alpha: 0.4),
                    elevation: 8,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          '🚀 Diffuser la notification',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
