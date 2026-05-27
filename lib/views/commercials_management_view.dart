import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/constants/app_colors.dart';
import '../widgets/modern_card.dart';
import '../models/app_user_model.dart';

enum CommercialDateFilter {
  all,
  today,
  last7days,
  last30days,
  custom,
}

class _CommercialRawData {
  final AppUserModel commercial;
  final List<Map<String, dynamic>> allClients;
  final List<Map<String, dynamic>> allOrders;

  _CommercialRawData({
    required this.commercial,
    required this.allClients,
    required this.allOrders,
  });
}

class _CommercialFilteredData {
  final AppUserModel commercial;
  final int clientsCount;
  final int ordersCount;
  final double salesTotal;
  final List<Map<String, dynamic>> filteredClients;
  final List<Map<String, dynamic>> filteredOrders;

  _CommercialFilteredData({
    required this.commercial,
    required this.clientsCount,
    required this.ordersCount,
    required this.salesTotal,
    required this.filteredClients,
    required this.filteredOrders,
  });
}

class CommercialsManagementView extends StatefulWidget {
  const CommercialsManagementView({super.key});

  @override
  State<CommercialsManagementView> createState() => _CommercialsManagementViewState();
}

class _CommercialsManagementViewState extends State<CommercialsManagementView> {
  bool _loading = false;
  List<_CommercialRawData> _rawPerformance = [];
  List<_CommercialFilteredData> _filteredPerformance = [];

  final _searchController = TextEditingController();
  String _searchQuery = '';
  CommercialDateFilter _selectedDateFilter = CommercialDateFilter.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _loadPerformance();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isWithinDateRange(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (_selectedDateFilter) {
      case CommercialDateFilter.today:
        return date.isAfter(todayStart);
      case CommercialDateFilter.last7days:
        final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
        return date.isAfter(sevenDaysAgo);
      case CommercialDateFilter.last30days:
        final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));
        return date.isAfter(thirtyDaysAgo);
      case CommercialDateFilter.custom:
        if (_customStartDate != null) {
          final isAfterStart = date.isAfter(_customStartDate!);
          final isBeforeEnd = _customEndDate == null || 
              date.isBefore(_customEndDate!.add(const Duration(days: 1)));
          return isAfterStart && isBeforeEnd;
        }
        return true;
      case CommercialDateFilter.all:
        return true;
    }
  }

  Future<void> _loadPerformance() async {
    setState(() => _loading = true);
    try {
      // 1. Fetch the ID of the commercial role
      final roleRow = await Supabase.instance.client
          .from('roles')
          .select('id')
          .eq('name', 'commercial')
          .maybeSingle();

      if (roleRow == null) {
        setState(() => _loading = false);
        return;
      }
      final commercialRoleId = roleRow['id'] as int;

      // 2. Fetch all commercials
      final usersRows = await Supabase.instance.client
          .from('users')
          .select()
          .eq('role_id', commercialRoleId);

      final commercials = (usersRows as List)
          .cast<Map<String, dynamic>>()
          .map((e) => AppUserModel.fromJson(e))
          .toList();

      final List<_CommercialRawData> rawList = [];

      for (final com in commercials) {
        if (com.id == null) continue;

        // Fetch referred clients
        final clientRows = await Supabase.instance.client
            .from('users')
            .select('id, name, nom, phone, created_at')
            .eq('referrer_id', com.id!);

        final clientList = (clientRows as List).cast<Map<String, dynamic>>();

        List<Map<String, dynamic>> orderList = [];

        if (clientList.isNotEmpty) {
          final clientIds = clientList.map((c) => c['id'] as String).toList();
          final orderRows = await Supabase.instance.client
              .from('orders')
              .select('id, user_id, total_price, status, created_at, users!orders_user_id_fkey(name, nom)')
              .inFilter('user_id', clientIds)
              .order('created_at', ascending: false);

          orderList = (orderRows as List).cast<Map<String, dynamic>>();
        }

        rawList.add(_CommercialRawData(
          commercial: com,
          allClients: clientList,
          allOrders: orderList,
        ));
      }

      _rawPerformance = rawList;
      _applyFilters();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement : $e')),
        );
      }
    }
  }

  void _applyFilters() {
    final List<_CommercialFilteredData> filteredList = [];

    for (final raw in _rawPerformance) {
      // 1. Filter clients by date
      final filteredClients = raw.allClients.where((c) {
        if (c['created_at'] == null) return false;
        final date = DateTime.parse(c['created_at'] as String);
        return _isWithinDateRange(date);
      }).toList();

      // 2. Filter orders by date
      final filteredOrders = raw.allOrders.where((o) {
        if (o['created_at'] == null) return false;
        final date = DateTime.parse(o['created_at'] as String);
        return _isWithinDateRange(date);
      }).toList();

      // 3. Calculate metrics
      final clientsCount = filteredClients.length;
      final ordersCount = filteredOrders.length;
      double salesTotal = 0.0;
      for (final o in filteredOrders) {
        final price = o['total_price'];
        if (price != null) {
          salesTotal += (price as num).toDouble();
        }
      }

      // 4. Filter by search query
      final query = _searchQuery.toLowerCase().trim();
      final com = raw.commercial;
      final name = (com.nom ?? com.name ?? '').toLowerCase();
      final email = com.email.toLowerCase();

      if (query.isEmpty || name.contains(query) || email.contains(query)) {
        filteredList.add(_CommercialFilteredData(
          commercial: com,
          clientsCount: clientsCount,
          ordersCount: ordersCount,
          salesTotal: salesTotal,
          filteredClients: filteredClients,
          filteredOrders: filteredOrders,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _filteredPerformance = filteredList;
        _loading = false;
      });
    }
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _sendSms(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final url = Uri.parse('sms:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _sendEmail(String email) async {
    if (email.isEmpty) return;
    final url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Suivi des Commerciaux',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPerformance,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Input
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _applyFilters();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Rechercher un commercial...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.mutedText),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.mutedText),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _applyFilters();
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                // Date filter chips
                _buildDateFilterChips(),
                const SizedBox(height: 8),
                // Main list
                Expanded(
                  child: _filteredPerformance.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_ind_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'Aucun résultat trouvé.',
                                style: TextStyle(color: AppColors.mutedText),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _filteredPerformance.length,
                          itemBuilder: (context, index) {
                            final data = _filteredPerformance[index];
                            final AppUserModel com = data.commercial;
                            final int clientsCount = data.clientsCount;
                            final int ordersCount = data.ordersCount;
                            final double salesTotal = data.salesTotal;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: ModernCard(
                                padding: const EdgeInsets.all(20),
                                onTap: () => _showCommercialDetailBottomSheet(data),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: AppColors.brandGreen.withValues(alpha: 0.15),
                                          child: Text(
                                            com.avatarLetter,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.brandGreenDark,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                com.nom ?? com.name ?? 'Commercial',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.text,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                com.email,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.mutedText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: AppColors.mutedText),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildIndicator('Clients', clientsCount.toString()),
                                        _buildDivider(),
                                        _buildIndicator('Commandes', ordersCount.toString()),
                                        _buildDivider(),
                                        _buildIndicator('Ventes', '${salesTotal.toStringAsFixed(0)} F'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDateFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _FilterChip(
            label: 'Toutes dates',
            isSelected: _selectedDateFilter == CommercialDateFilter.all,
            onTap: () {
              setState(() {
                _selectedDateFilter = CommercialDateFilter.all;
                _customStartDate = null;
                _customEndDate = null;
                _applyFilters();
              });
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: "Aujourd'hui",
            isSelected: _selectedDateFilter == CommercialDateFilter.today,
            onTap: () {
              setState(() {
                _selectedDateFilter = CommercialDateFilter.today;
                _customStartDate = null;
                _customEndDate = null;
                _applyFilters();
              });
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '7 derniers jours',
            isSelected: _selectedDateFilter == CommercialDateFilter.last7days,
            onTap: () {
              setState(() {
                _selectedDateFilter = CommercialDateFilter.last7days;
                _customStartDate = null;
                _customEndDate = null;
                _applyFilters();
              });
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '30 derniers jours',
            isSelected: _selectedDateFilter == CommercialDateFilter.last30days,
            onTap: () {
              setState(() {
                _selectedDateFilter = CommercialDateFilter.last30days;
                _customStartDate = null;
                _customEndDate = null;
                _applyFilters();
              });
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: _selectedDateFilter == CommercialDateFilter.custom && _customStartDate != null
                ? '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}'
                : 'Personnalisé...',
            isSelected: _selectedDateFilter == CommercialDateFilter.custom,
            color: AppColors.primary,
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2025),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _customStartDate != null && _customEndDate != null
                    ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
                    : null,
              );
              if (picked != null) {
                setState(() {
                  _selectedDateFilter = CommercialDateFilter.custom;
                  _customStartDate = picked.start;
                  _customEndDate = picked.end;
                  _applyFilters();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.mutedText, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.text),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: AppColors.border,
    );
  }

  void _showCommercialDetailBottomSheet(_CommercialFilteredData data) {
    final AppUserModel com = data.commercial;
    final List<Map<String, dynamic>> clients = data.filteredClients;
    final List<Map<String, dynamic>> orders = data.filteredOrders;
    final double avgBasket = data.ordersCount > 0 ? (data.salesTotal / data.ordersCount) : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.brandGreen.withValues(alpha: 0.15),
                          child: Text(
                            com.avatarLetter,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandGreenDark,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                com.nom ?? com.name ?? 'Commercial',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                com.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedText,
                                ),
                              ),
                              if (com.phone != null && com.phone!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  com.phone!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        if (com.phone != null && com.phone!.isNotEmpty) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _makeCall(com.phone),
                              icon: const Icon(Icons.call, size: 16),
                              label: const Text('Appeler'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _sendSms(com.phone),
                              icon: const Icon(Icons.sms_outlined, size: 16),
                              label: const Text('SMS'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.info,
                                side: const BorderSide(color: AppColors.info),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _sendEmail(com.email),
                            icon: const Icon(Icons.email_outlined, size: 16),
                            label: const Text('E-mail'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.mutedText,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 2.8,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                        children: [
                          _buildDetailStatCard('Clients Recrutés', '${data.clientsCount}'),
                          _buildDetailStatCard('Commandes parrainées', '${data.ordersCount}'),
                          _buildDetailStatCard('Ventes parrainées', '${data.salesTotal.toStringAsFixed(0)} F'),
                          _buildDetailStatCard('Panier Moyen parrainé', '${avgBasket.toStringAsFixed(0)} F'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: TabBar(
                      tabs: [
                        Tab(text: 'Clients parrainés'),
                        Tab(text: 'Commandes parrainées'),
                      ],
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.mutedText,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildClientsTab(clients, scrollController),
                        _buildOrdersTab(orders, scrollController),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDetailStatCard(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.mutedText, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.text),
          ),
        ),
      ],
    );
  }

  Widget _buildClientsTab(List<Map<String, dynamic>> clients, ScrollController scrollController) {
    if (clients.isEmpty) {
      return const Center(
        child: Text(
          'Aucun client parrainé pour cette période.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: clients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final c = clients[idx];
        final cName = c['nom'] as String? ?? c['name'] as String? ?? 'Client';
        final cPhone = c['phone'] as String? ?? 'Non renseigné';
        final String regDate = c['created_at'] != null
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(c['created_at'] as String))
            : '-';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tél: $cPhone',
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Rejoint le',
                    style: TextStyle(fontSize: 9, color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    regDate,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdersTab(List<Map<String, dynamic>> orders, ScrollController scrollController) {
    if (orders.isEmpty) {
      return const Center(
        child: Text(
          'Aucune commande passée par les filleuls pour cette période.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final o = orders[idx];
        final id = o['id'] ?? '-';
        final double price = o['total_price'] != null ? (o['total_price'] as num).toDouble() : 0.0;
        final status = o['status'] as String? ?? 'pending';
        final String orderDate = o['created_at'] != null
            ? DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(o['created_at'] as String))
            : '-';

        // Extract client name
        final userObj = o['users'];
        String clientName = 'Client';
        if (userObj is Map) {
          clientName = userObj['nom'] as String? ?? userObj['name'] as String? ?? 'Client';
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commande #$id - $clientName',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      orderDate,
                      style: const TextStyle(fontSize: 10, color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${price.toStringAsFixed(0)} F',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusBadge(status),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = Colors.amber;
        label = 'En attente';
        break;
      case 'processing':
        color = Colors.cyan;
        label = 'En cours';
        break;
      case 'shipped':
        color = Colors.blue;
        label = 'Expédiée';
        break;
      case 'delivered':
        color = AppColors.success;
        label = 'Livrée';
        break;
      case 'cancelled':
        color = AppColors.danger;
        label = 'Annulée';
        break;
      default:
        color = AppColors.mutedText;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.accent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}
