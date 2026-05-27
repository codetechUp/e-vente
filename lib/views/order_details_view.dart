import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user_model.dart';
import '../models/delivery_model.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../services/deliveries_service.dart';
import '../services/order_items_service.dart';
import '../services/orders_service.dart';
import '../services/invoices_service.dart';
import '../services/pdf_invoice_service.dart';
import '../utils/constants/app_colors.dart';
import '../providers/auth_provider.dart';

const _statusList = [
  'pending',
  'processing',
  'shipped',
  'delivered',
  'cancelled',
];

String statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'En attente';
    case 'processing':
      return 'En cours';
    case 'shipped':
      return 'Expédiée';
    case 'delivered':
      return 'Livrée';
    case 'cancelled':
      return 'Annulée';
    default:
      return status;
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'delivered':
      return AppColors.success;
    case 'shipped':
      return const Color(0xFF3B82F6);
    case 'processing':
      return AppColors.accent;
    case 'cancelled':
      return AppColors.danger;
    default:
      return AppColors.mutedText;
  }
}

IconData statusIcon(String status) {
  switch (status) {
    case 'delivered':
      return Icons.check_circle;
    case 'shipped':
      return Icons.local_shipping;
    case 'processing':
      return Icons.hourglass_empty;
    case 'cancelled':
      return Icons.cancel;
    default:
      return Icons.pending;
  }
}

class OrderDetailsView extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsView({super.key, required this.order});

  @override
  State<OrderDetailsView> createState() => _OrderDetailsViewState();
}

class _OrderDetailsViewState extends State<OrderDetailsView> {
  final _ordersService = OrdersService();
  final _itemsService = OrderItemsService();
  final _deliveriesService = DeliveriesService();

  bool _loading = false;
  late String _status;

  List<AppUserModel> _livreurs = [];
  String? _selectedLivreurId;
  String? _currentLivreurId;

  // Client exact GPS coordinates
  double? _clientLatitude;
  double? _clientLongitude;
  bool _fetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
    _loadLivreurs();
    _loadCurrentDelivery();
    _loadClientLocation();
  }

  Future<void> _loadLivreurs() async {
    try {
      final rows = await Supabase.instance.client
          .from('users')
          .select('*, roles(name)')
          .order('name', ascending: true);

      final all = (rows as List)
          .cast<Map<String, dynamic>>()
          .map((e) => AppUserModel.fromJson(e))
          .toList();

      final livreurRoleRows = await Supabase.instance.client
          .from('roles')
          .select()
          .ilike('name', 'livreur')
          .maybeSingle();

      if (livreurRoleRows == null) return;
      final livreurRoleId = livreurRoleRows['id'] as int?;
      if (livreurRoleId == null) return;

      if (!mounted) return;
      setState(() {
        final uniqueLivreurs = <String, AppUserModel>{};
        for (final user in all) {
          final userId = user.id;
          if (user.roleId != livreurRoleId ||
              !user.isActive ||
              userId == null) {
            continue;
          }
          uniqueLivreurs[userId] = user;
        }

        _livreurs = uniqueLivreurs.values.toList()
          ..sort(
            (a, b) => ((a.name?.trim().isNotEmpty ?? false) ? a.name! : a.email)
                .toLowerCase()
                .compareTo(
                  ((b.name?.trim().isNotEmpty ?? false) ? b.name! : b.email)
                      .toLowerCase(),
                ),
          );
      });
    } catch (_) {}
  }

  Future<void> _loadCurrentDelivery() async {
    final orderId = widget.order.id;
    if (orderId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('deliveries')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();
      if (row != null) {
        final d = DeliveryModel.fromJson(row);
        if (!mounted) return;
        setState(() {
          _selectedLivreurId = d.deliveryPersonId;
          _currentLivreurId = d.deliveryPersonId;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadClientLocation() async {
    final userId = widget.order.userId;
    if (userId == null) return;
    if (mounted) setState(() => _fetchingLocation = true);
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('latitude, longitude')
          .eq('id', userId)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _clientLatitude = data['latitude'] != null ? (data['latitude'] as num).toDouble() : null;
          _clientLongitude = data['longitude'] != null ? (data['longitude'] as num).toDouble() : null;
        });
      }
    } catch (_) {
      // Ignore
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _openClientLocation() async {
    final order = widget.order;
    Uri url;
    if (_clientLatitude != null && _clientLongitude != null) {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$_clientLatitude,$_clientLongitude',
      );
    } else if (order.deliveryAddress?.trim().isNotEmpty == true) {
      final query = Uri.encodeComponent(order.deliveryAddress!);
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    } else if (order.userAdresse?.trim().isNotEmpty == true) {
      final query = Uri.encodeComponent(order.userAdresse!);
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune adresse ou coordonnée de livraison disponible.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'ouvrir l\'application de cartes.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final id = widget.order.id;
    if (id == null) return;

    setState(() => _loading = true);
    try {
      await _ordersService.updateById(id, {'status': _status});

      if (_selectedLivreurId != null &&
          _selectedLivreurId != _currentLivreurId) {
        final existingRow = await Supabase.instance.client
            .from('deliveries')
            .select()
            .eq('order_id', id)
            .maybeSingle();

        if (existingRow != null) {
          final existingId = existingRow['id'] as int;
          await _deliveriesService.updateById(existingId, {
            'delivery_person_id': _selectedLivreurId,
          });
        } else {
          await _deliveriesService.create(
            DeliveryModel(
              orderId: id,
              deliveryPersonId: _selectedLivreurId,
              status: _status == 'pending' ? 'pending' : _status,
            ),
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Commande mise à jour.')));
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
    final auth = context.watch<AuthProvider>();
    final order = widget.order;
    final livreurIds = _livreurs
        .map((l) => l.id)
        .whereType<String>()
        .toList(growable: false);
    final selectedLivreurValue =
        _selectedLivreurId != null &&
            livreurIds.where((id) => id == _selectedLivreurId).length == 1
        ? _selectedLivreurId
        : null;

    final hasCoordinates = _clientLatitude != null && _clientLongitude != null;
    final hasAddress = order.deliveryAddress?.trim().isNotEmpty == true || 
                       order.userAdresse?.trim().isNotEmpty == true;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Détails de la commande',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          if (auth.isAdmin || auth.isPreparateur)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'Imprimer la facture',
              onPressed: () => _showPrintOptionsDialog(),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // 1. Order Title & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Commande #${order.id ?? '-'}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.createdAt != null
                                ? DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(order.createdAt!)
                                : '-',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor(order.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon(order.status),
                            color: statusColor(order.status),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel(order.status),
                            style: TextStyle(
                              color: statusColor(order.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. Large Total Amount Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MONTANT TOTAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mutedText,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(order.totalPrice ?? 0).toStringAsFixed(0)} F',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Client & Delivery Information
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CLIENT & LIVRAISON',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mutedText,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (order.userNom?.isNotEmpty == true) ...[
                        _buildInfoItem(Icons.person_outline, 'Nom', order.userNom!),
                        const SizedBox(height: 12),
                      ],
                      if (order.userPhone?.isNotEmpty == true) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(Icons.phone_outlined, 'Téléphone', order.userPhone!),
                            ),
                            IconButton(
                              icon: const Icon(Icons.call, color: AppColors.primary, size: 20),
                              onPressed: () async {
                                final url = Uri.parse('tel:${order.userPhone}');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (order.deliveryAddress?.isNotEmpty == true) ...[
                        _buildInfoItem(Icons.location_on_outlined, 'Adresse de livraison', order.deliveryAddress!),
                        const SizedBox(height: 12),
                      ] else if (order.userAdresse?.isNotEmpty == true) ...[
                        _buildInfoItem(Icons.location_on_outlined, 'Adresse client', order.userAdresse!),
                        const SizedBox(height: 12),
                      ],
                      if (order.desiredDeliveryDate != null) ...[
                        _buildInfoItem(
                          Icons.calendar_today_outlined,
                          'Livraison souhaitée',
                          "${DateFormat('dd MMM yyyy', 'fr_FR').format(order.desiredDeliveryDate!)}${order.deliverySlot != null ? ', ${order.deliverySlot}' : ''}",
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Location Button
                      if (_fetchingLocation)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (hasCoordinates || hasAddress)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openClientLocation,
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Localiser le client'),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (hasCoordinates ? AppColors.success : Colors.orange).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    hasCoordinates ? 'GPS' : 'Adresse',
                                    style: TextStyle(
                                      color: hasCoordinates ? AppColors.success : Colors.orange,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        )
                      else
                        const Text(
                          'Aucune localisation disponible (ni adresse, ni GPS)',
                          style: TextStyle(fontSize: 12, color: AppColors.danger, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Order Items
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ARTICLES COMMANDÉS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mutedText,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<OrderItemModel>>(
                        future: order.id == null
                            ? Future.value(const [])
                            : _itemsService.getAllForOrder(order.id!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Text('Erreur: ${snapshot.error}');
                          }
                          final items = snapshot.data ?? const [];
                          if (items.isEmpty) {
                            return const Text('Aucun article commandé.');
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 20),
                            itemBuilder: (context, idx) {
                              final item = items[idx];
                              return Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      color: AppColors.background,
                                      child: (item.productImageUrl?.isNotEmpty == true)
                                          ? Image.network(
                                              item.productImageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 20),
                                            )
                                          : const Icon(Icons.image_outlined, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName ?? 'Produit',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${(item.price ?? 0).toStringAsFixed(0)} F × ${item.quantity}',
                                          style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${((item.price ?? 0) * item.quantity).toStringAsFixed(0)} F',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Management Controls (Admin & Preparateur only)
                if (auth.isAdmin || auth.isPreparateur)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTIONS ADMINISTRATIVES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mutedText,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(
                            labelText: 'Statut de la commande',
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          items: _statusList.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(statusLabel(s)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _status = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String?>(
                          value: selectedLivreurValue,
                          decoration: const InputDecoration(
                            labelText: 'Livreur assigné',
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Aucun livreur'),
                            ),
                            ..._livreurs.map((l) {
                              return DropdownMenuItem<String?>(
                                value: l.id,
                                child: Text((l.name?.trim().isNotEmpty ?? false) ? l.name! : l.email),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedLivreurId = val);
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Enregistrer les modifications', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.mutedText),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.mutedText, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showPrintOptionsDialog() async {
    final order = widget.order;
    if (order.id == null) return;

    // Load items first
    final items = await _itemsService.getAllForOrder(order.id!);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Imprimer la facture',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Choisissez le format de facture à imprimer ou télécharger.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                _printInvoice(items, isA4: false);
              },
              child: const Text('Ticket 80mm', style: TextStyle(color: AppColors.brandGreenDark, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                _printInvoice(items, isA4: true);
              },
              child: const Text('Format A4 (PDF)', style: TextStyle(color: AppColors.brandGreenDark, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printInvoice(List<OrderItemModel> items, {required bool isA4}) async {
    final order = widget.order;
    final id = order.id;
    if (id == null) return;

    final auth = context.read<AuthProvider>();
    setState(() => _loading = true);
    try {
      final invoicesService = InvoicesService();
      final invoice = await invoicesService.getOrCreateInvoiceForOrder(id, auth.user?.id ?? '');

      await PdfInvoiceService.printInvoice(
        order: order,
        items: items,
        invoiceNumber: invoice.invoiceNumber,
        isA4: isA4,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'impression : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
