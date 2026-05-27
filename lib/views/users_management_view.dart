import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/app_user_model.dart';
import '../models/role_model.dart';
import '../services/app_users_service.dart';
import '../services/roles_service.dart';
import '../services/location_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/client_qr_scanner_dialog.dart';

class UsersManagementView extends StatefulWidget {
  const UsersManagementView({super.key});

  @override
  State<UsersManagementView> createState() => _UsersManagementViewState();
}

class _UsersManagementViewState extends State<UsersManagementView> {
  final _usersService = AppUsersService();
  final _rolesService = RolesService();

  late Future<_UsersPageData> _future;
  
  // Search & Filter state
  String _searchQuery = '';
  int? _selectedRoleId;
  String _selectedStatus = 'all'; // 'all', 'active', 'inactive', 'pending'
  
  // Selected user for Desktop Side Panel
  AppUserModel? _selectedUser;
  bool _isAddingUser = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_UsersPageData> _load() async {
    final roles = await _rolesService.getAll();
    final users = await _usersService.getAll();
    return _UsersPageData(users: users, roles: roles);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
      // Keep selected user updated if possible, or reset
      _selectedUser = null;
      _isAddingUser = false;
    });
  }

  Future<void> _toggleActive(AppUserModel user, bool value) async {
    if (user.id == null) return;

    try {
      if (kDebugMode) {
        debugPrint('[UsersManagementView] toggle active user id=${user.id} value=$value');
      }
      await _usersService.updateById(user.id!, {'is_active': value});
      await _reload();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Utilisateur activé' : 'Utilisateur désactivé'),
          backgroundColor: value ? AppColors.success : AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _openAddUser(List<RoleModel> roles, bool isDesktop) {
    if (isDesktop) {
      setState(() {
        _isAddingUser = true;
        _selectedUser = null;
      });
    } else {
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AddUserSheet(
          roles: roles,
          onSave: (newUser) async {
            await _usersService.create(newUser);
          },
        ),
      ).then((created) {
        if (created == true) _reload();
      });
    }
  }

  void _openEditUser(AppUserModel user, List<RoleModel> roles, bool isDesktop) {
    if (isDesktop) {
      setState(() {
        _selectedUser = user;
        _isAddingUser = false;
      });
    } else {
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _EditUserSheet(
          user: user,
          roles: roles,
          onSave: (patch) async {
            if (user.id == null) return;
            await _usersService.updateById(user.id!, patch);
          },
        ),
      ).then((updated) {
        if (updated == true) _reload();
      });
    }
  }

  bool _isPending(AppUserModel u) {
    return u.email.endsWith('@gros-divers.sn') && (u.name == null || u.name!.isEmpty || u.id!.length > 30);
  }

  List<AppUserModel> _filterUsers(List<AppUserModel> users, List<RoleModel> roles) {
    return users.where((u) {
      // 1. Search Query filter (matches name, phone, or email)
      final query = _searchQuery.toLowerCase().trim();
      final nameMatch = (u.name ?? '').toLowerCase().contains(query) || (u.nom ?? '').toLowerCase().contains(query);
      final phoneMatch = (u.phone ?? '').toLowerCase().contains(query);
      final emailMatch = u.email.toLowerCase().contains(query);
      
      if (query.isNotEmpty && !nameMatch && !phoneMatch && !emailMatch) {
        return false;
      }
      
      // 2. Role filter
      if (_selectedRoleId != null && u.roleId != _selectedRoleId) {
        return false;
      }
      
      // 3. Status filter
      if (_selectedStatus == 'active') {
        return u.isActive && !_isPending(u);
      } else if (_selectedStatus == 'inactive') {
        return !u.isActive;
      } else if (_selectedStatus == 'pending') {
        return _isPending(u);
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 950;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestion des Utilisateurs'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: () => ClientQrScannerDialog.show(context),
            icon: const Icon(LucideIcons.qrCode, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Scanner un client',
          ),
          IconButton(
            onPressed: _reload,
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
        ],
        shape: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      body: FutureBuilder<_UsersPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.shieldAlert, size: 48, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text('Erreur: ${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 180,
                      child: AppButton(label: 'Réessayer', onPressed: _reload),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) return const SizedBox.shrink();

          final filteredUsers = _filterUsers(data.users, data.roles);
          final rolesById = {for (final r in data.roles) if (r.id != null) r.id!: r};

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left side (Main Area)
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Stats panel
                    SliverToBoxAdapter(
                      child: _buildStatsGrid(data.users, isDesktop),
                    ),
                    
                    // Search & Filters panel
                    SliverToBoxAdapter(
                      child: _buildFiltersPanel(data.roles, isDesktop),
                    ),

                    // User List / Grid
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding, vertical: 8),
                      sliver: filteredUsers.isEmpty
                          ? SliverToBoxAdapter(child: _buildEmptyState())
                          : isDesktop
                              ? SliverToBoxAdapter(
                                  child: _buildDesktopTable(filteredUsers, rolesById, data.roles),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final user = filteredUsers[index];
                                      final roleName = user.roleId == null
                                          ? 'Client'
                                          : (rolesById[user.roleId!]?.name ?? 'Client');
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _UserCard(
                                          user: user,
                                          roleName: roleName,
                                          isPending: _isPending(user),
                                          onEdit: () => _openEditUser(user, data.roles, false),
                                          onToggle: (v) => _toggleActive(user, v),
                                        ),
                                      );
                                    },
                                    childCount: filteredUsers.length,
                                  ),
                                ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),

              // Right side (Desktop Side Panel)
              if (isDesktop)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: (_selectedUser != null || _isAddingUser) ? 420 : 0,
                  curve: Curves.easeInOut,
                  child: SingleChildScrollView(
                    child: Container(
                      height: MediaQuery.of(context).size.height - AppBar().preferredSize.height - 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(left: BorderSide(color: AppColors.border, width: 1.5)),
                      ),
                      child: (_selectedUser != null || _isAddingUser)
                          ? ClipRect(
                              child: _isAddingUser
                                  ? _AddUserPanel(
                                      roles: data.roles,
                                      onCancel: () => setState(() => _isAddingUser = false),
                                      onSave: (newUser) async {
                                        await _usersService.create(newUser);
                                        await _reload();
                                      },
                                    )
                                  : _EditUserPanel(
                                      user: _selectedUser!,
                                      roles: data.roles,
                                      onCancel: () => setState(() => _selectedUser = null),
                                      onSave: (patch) async {
                                        if (_selectedUser?.id == null) return;
                                        await _usersService.updateById(_selectedUser!.id!, patch);
                                        await _reload();
                                      },
                                    ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<_UsersPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData || isDesktop) return const SizedBox.shrink();
          return FloatingActionButton(
            backgroundColor: AppColors.brandGreen,
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () => _openAddUser(snapshot.data!.roles, false),
            child: const Icon(LucideIcons.plus, color: Colors.white),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(List<AppUserModel> allUsers, bool isDesktop) {
    final total = allUsers.length;
    final active = allUsers.where((u) => u.isActive && !_isPending(u)).length;
    final pending = allUsers.where(_isPending).length;
    final commercial = allUsers.where((u) => u.roleId == 3 || u.roleId == 4).length; // Adjust role ID logic

    final cards = [
      _StatCard(
        title: 'Total Utilisateurs',
        value: total.toString(),
        icon: LucideIcons.users,
        color: Colors.indigo,
      ),
      _StatCard(
        title: 'Utilisateurs Actifs',
        value: active.toString(),
        icon: LucideIcons.userCheck,
        color: AppColors.success,
        percentage: total > 0 ? (active / total) : 0.0,
      ),
      _StatCard(
        title: 'Pré-enregistrés',
        value: pending.toString(),
        icon: LucideIcons.userX,
        color: Colors.orange,
        isAlert: pending > 0,
      ),
      _StatCard(
        title: 'Commerciaux',
        value: commercial.toString(),
        icon: LucideIcons.shieldAlert,
        color: Colors.teal,
      ),
    ];

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSizes.padding, AppSizes.padding, AppSizes.padding, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: cards.map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: c,
                ),
              )).toList(),
            );
          }
        ),
      );
    } else {
      return SizedBox(
        height: 120,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding - 4, vertical: 12),
          children: cards.map((c) => Container(
            width: 170,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: c,
          )).toList(),
        ),
      );
    }
  }

  Widget _buildFiltersPanel(List<RoleModel> roles, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.padding, vertical: 12),
      padding: const EdgeInsets.all(AppSizes.paddingSm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row with Search field + Add User Button on Desktop
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, téléphone, e-mail...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.mutedText),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.padding,
                      vertical: 18,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.95),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  onPressed: () => _openAddUser(roles, true),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('Ajouter Client', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
                    elevation: 0,
                  ),
                ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          // Chips filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(LucideIcons.filter, size: 16, color: AppColors.mutedText),
                const SizedBox(width: 10),
                
                // Role filter chips
                _FilterChip(
                  label: 'Tous les rôles',
                  selected: _selectedRoleId == null,
                  onSelected: (_) => setState(() => _selectedRoleId = null),
                ),
                ...roles.where((r) => r.id != null).map((r) {
                  return _FilterChip(
                    label: r.name,
                    selected: _selectedRoleId == r.id,
                    onSelected: (_) => setState(() => _selectedRoleId = r.id),
                  );
                }),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('|', style: TextStyle(color: AppColors.border)),
                ),

                // Status filter chips
                _FilterChip(
                  label: 'Tous les statuts',
                  selected: _selectedStatus == 'all',
                  onSelected: (_) => setState(() => _selectedStatus = 'all'),
                ),
                _FilterChip(
                  label: 'Actifs',
                  selected: _selectedStatus == 'active',
                  onSelected: (_) => setState(() => _selectedStatus = 'active'),
                ),
                _FilterChip(
                  label: 'Pré-enregistrés',
                  selected: _selectedStatus == 'pending',
                  onSelected: (_) => setState(() => _selectedStatus = 'pending'),
                ),
                _FilterChip(
                  label: 'Inactifs',
                  selected: _selectedStatus == 'inactive',
                  onSelected: (_) => setState(() => _selectedStatus = 'inactive'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingLg * 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.users, size: 56, color: AppColors.mutedText),
          const SizedBox(height: 14),
          Text(
            'Aucun utilisateur trouvé',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Essayez de modifier votre recherche ou vos filtres.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(
    List<AppUserModel> users,
    Map<int, RoleModel> rolesById,
    List<RoleModel> roles,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        dataRowHeight: 68,
        columnSpacing: 20,
        showCheckboxColumn: false,
        columns: const [
          DataColumn(label: Text('Nom / Contact', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
          DataColumn(label: Text('Téléphone', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
          DataColumn(label: Text('E-mail', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
          DataColumn(label: Text('Rôle', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
          DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
        ],
        rows: users.map((u) {
          final isPendingUser = _isPending(u);
          final roleName = u.roleId == null ? 'Client' : (rolesById[u.roleId!]?.name ?? 'Client');
          final active = u.isActive;
          
          return DataRow(
            onSelectChanged: (_) => _openEditUser(u, roles, true),
            cells: [
              DataCell(
                Row(
                  children: [
                    _Avatar(user: u, isPending: isPendingUser),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        (u.name != null && u.name!.trim().isNotEmpty) ? u.name! : (u.nom ?? 'Sans nom'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(Text(u.phone ?? '-', style: const TextStyle(fontWeight: FontWeight.w500))),
              DataCell(
                Text(
                  isPendingUser ? '-' : u.email,
                  style: TextStyle(
                    color: isPendingUser ? AppColors.textLight : AppColors.text,
                    fontStyle: isPendingUser ? FontStyle.italic : FontStyle.normal,
                    fontSize: 13,
                  ),
                ),
              ),
              DataCell(_RoleBadge(roleName: roleName)),
              DataCell(_StatusBadge(isActive: active, isPending: isPendingUser)),
              DataCell(
                Row(
                  children: [
                    Switch(
                      value: active,
                      activeThumbColor: AppColors.accent,
                      activeTrackColor: AppColors.accent.withValues(alpha: 0.35),
                      onChanged: (v) => _toggleActive(u, v),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.edit, size: 16),
                      color: AppColors.mutedText,
                      onPressed: () => _openEditUser(u, roles, true),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// Subwidgets

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? percentage;
  final bool isAlert;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.percentage,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: isAlert ? Colors.orange.withValues(alpha: 0.5) : AppColors.border,
          width: isAlert ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mutedText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    if (percentage != null) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          value: percentage,
                          strokeWidth: 3,
                          backgroundColor: Colors.grey.shade100,
                          color: AppColors.brandGreen,
                        ),
                      ),
                    ],
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        selected: selected,
        onSelected: onSelected,
        selectedColor: AppColors.brandGreen,
        backgroundColor: AppColors.background,
        elevation: selected ? 2 : 0,
        pressElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppColors.brandGreen : AppColors.border,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUserModel user;
  final String roleName;
  final bool isPending;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  const _UserCard({
    required this.user,
    required this.roleName,
    required this.isPending,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final active = user.isActive;
    
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Avatar(user: user, isPending: isPending),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user.name != null && user.name!.trim().isNotEmpty)
                          ? user.name!
                          : (user.nom != null && user.nom!.trim().isNotEmpty)
                              ? user.nom!
                              : 'Sans nom',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.phone ?? 'Pas de contact',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.edit, size: 18),
                color: AppColors.mutedText,
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RoleBadge(roleName: roleName),
              Row(
                children: [
                  _StatusBadge(isActive: active, isPending: isPending),
                  const SizedBox(width: 8),
                  Switch(
                    value: active,
                    activeThumbColor: AppColors.accent,
                    activeTrackColor: AppColors.accent.withValues(alpha: 0.35),
                    onChanged: onToggle,
                  ),
                ],
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.userX, size: 14, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Créé par l\'admin. En attente de première connexion par téléphone.',
                      style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final AppUserModel user;
  final bool isPending;

  const _Avatar({required this.user, required this.isPending});

  Color _roleColor(int? roleId) {
    if (isPending) return Colors.orange;
    switch (roleId) {
      case 1: // client
        return Colors.blue;
      case 2: // preparateur
        return Colors.indigo;
      case 3: // commercial
      case 4: // commercial manager
        return Colors.teal;
      case 5: // admin
        return AppColors.brandGreenDark;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(user.roleId);
    
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        user.avatarLetter,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String roleName;

  const _RoleBadge({required this.roleName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Text(
        roleName.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.brandGreenDark,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  final bool isPending;

  const _StatusBadge({required this.isActive, required this.isPending});

  @override
  Widget build(BuildContext context) {
    final label = isPending 
        ? 'EN ATTENTE' 
        : (isActive ? 'ACTIF' : 'INACTIF');
        
    final color = isPending 
        ? Colors.orange 
        : (isActive ? AppColors.success : AppColors.danger);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ADD USER BOTTOM SHEET / PANEL

class _AddUserSheet extends StatelessWidget {
  final List<RoleModel> roles;
  final Future<void> Function(AppUserModel user) onSave;

  const _AddUserSheet({required this.roles, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSizes.padding,
        right: AppSizes.padding,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
      ),
      child: SafeArea(
        top: false,
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
            const SizedBox(height: 16),
            _AddUserPanel(
              roles: roles,
              onCancel: () => Navigator.of(context).pop(false),
              onSave: (u) async {
                await onSave(u);
                if (context.mounted) Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddUserPanel extends StatefulWidget {
  final List<RoleModel> roles;
  final VoidCallback onCancel;
  final Future<void> Function(AppUserModel user) onSave;

  const _AddUserPanel({
    required this.roles,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_AddUserPanel> createState() => _AddUserPanelState();
}

class _AddUserPanelState extends State<_AddUserPanel> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  RoleModel? _role;
  bool _loading = false;
  
  double? _latitude;
  double? _longitude;
  bool _gpsLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to client role
    _role = widget.roles.firstWhere(
      (r) => r.name.toLowerCase() == 'client',
      orElse: () => widget.roles.isEmpty ? const RoleModel(name: '') : widget.roles.first,
    );
    if (_role?.id == null) _role = null;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _captureGPSLocation() async {
    setState(() => _gpsLoading = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
        final addr = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
        if (addr != null && addr.isNotEmpty) {
          setState(() {
            _address.text = addr;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d’obtenir la position GPS.')),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GPS Error: $e');
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final name = _name.text.trim();
      final rawPhone = _phone.text.trim().replaceAll(' ', '');
      final phone = '+221$rawPhone';
      final email = _email.text.trim().isEmpty ? '' : _email.text.trim();
      final address = _address.text.trim();

      final randomUuid = const Uuid().v4();

      final newUser = AppUserModel(
        id: randomUuid,
        name: name,
        nom: name,
        email: email,
        phone: phone,
        adresse: address.isEmpty ? null : address,
        roleId: _role?.id,
        isActive: true,
        latitude: _latitude,
        longitude: _longitude,
      );

      await widget.onSave(newUser);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ajouter un utilisateur',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(LucideIcons.userX),
                  color: AppColors.mutedText,
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _name,
              label: 'Nom complet *',
              hint: 'Ex: Mamadou Diallo',
              prefixIcon: const Icon(LucideIcons.users, size: 18),
              validator: (v) => v == null || v.trim().isEmpty ? 'Nom complet obligatoire' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _phone,
              label: 'Numéro de téléphone (sans +221) *',
              hint: 'Ex: 771234567',
              keyboardType: TextInputType.phone,
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                child: Text('+221', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Téléphone obligatoire';
                final cleaned = v.trim().replaceAll(' ', '');
                if (cleaned.length != 9 || !cleaned.startsWith('7')) {
                  return 'Le numéro doit contenir 9 chiffres et commencer par 7';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _email,
              label: 'E-mail (Optionnel)',
              hint: 'Ex: client@mail.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(LucideIcons.users, size: 18),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _address,
              label: 'Adresse de livraison (Optionnel)',
              hint: 'Ex: Parcelles Assainies U24',
              prefixIcon: const Icon(LucideIcons.mapPin, size: 18),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Position GPS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (_latitude != null && _longitude != null)
                            ? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                            : 'Aucune position GPS',
                        style: TextStyle(
                          color: (_latitude != null) ? AppColors.brandGreenDark : AppColors.mutedText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _gpsLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton.filled(
                        onPressed: _captureGPSLocation,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.brandGreen.withValues(alpha: 0.12),
                          foregroundColor: AppColors.brandGreenDark,
                        ),
                        icon: const Icon(LucideIcons.mapPin, size: 18),
                        tooltip: 'Détecter la position GPS',
                      ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RoleModel>(
                  value: _role,
                  isExpanded: true,
                  hint: const Text('Choisir un rôle'),
                  items: widget.roles
                      .where((r) => r.id != null)
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _role = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Ajouter',
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// EDIT USER BOTTOM SHEET / PANEL

class _EditUserSheet extends StatelessWidget {
  final AppUserModel user;
  final List<RoleModel> roles;
  final Future<void> Function(Map<String, dynamic> patch) onSave;

  const _EditUserSheet({
    required this.user,
    required this.roles,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSizes.padding,
        right: AppSizes.padding,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
      ),
      child: SafeArea(
        top: false,
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
            const SizedBox(height: 16),
            _EditUserPanel(
              user: user,
              roles: roles,
              onCancel: () => Navigator.of(context).pop(false),
              onSave: (patch) async {
                await onSave(patch);
                if (context.mounted) Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EditUserPanel extends StatefulWidget {
  final AppUserModel user;
  final List<RoleModel> roles;
  final VoidCallback onCancel;
  final Future<void> Function(Map<String, dynamic> patch) onSave;

  const _EditUserPanel({
    required this.user,
    required this.roles,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_EditUserPanel> createState() => _EditUserPanelState();
}

class _EditUserPanelState extends State<_EditUserPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;

  RoleModel? _role;
  late bool _isActive;
  bool _loading = false;

  double? _latitude;
  double? _longitude;
  bool _gpsLoading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name ?? widget.user.nom ?? '');
    _email = TextEditingController(text: widget.user.email);
    _phone = TextEditingController(text: widget.user.phone ?? '');
    _address = TextEditingController(text: widget.user.adresse ?? '');
    _isActive = widget.user.isActive;
    _latitude = widget.user.latitude;
    _longitude = widget.user.longitude;
    
    _role = widget.roles.firstWhere(
      (r) => r.id != null && r.id == widget.user.roleId,
      orElse: () => widget.roles.isEmpty ? const RoleModel(name: '') : widget.roles.first,
    );
    if (_role?.id == null) _role = null;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _captureGPSLocation() async {
    setState(() => _gpsLoading = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
        final addr = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
        if (addr != null && addr.isNotEmpty) {
          setState(() {
            _address.text = addr;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d’obtenir la position GPS.')),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GPS Error: $e');
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final patch = <String, dynamic>{
        'name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'nom': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'adresse': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'role_id': _role?.id,
        'is_active': _isActive,
        'latitude': _latitude,
        'longitude': _longitude,
      };

      await widget.onSave(patch);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Modifier l\'utilisateur',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(LucideIcons.userX),
                  color: AppColors.mutedText,
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _name,
              label: 'Nom complet',
              hint: 'Ex: Mamadou Diallo',
              prefixIcon: const Icon(LucideIcons.users, size: 18),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _phone,
              label: 'Téléphone',
              hint: 'Ex: +221 77...',
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(LucideIcons.users, size: 18),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _email,
              label: 'E-mail',
              hint: 'Ex: client@mail.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(LucideIcons.users, size: 18),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'E-mail obligatoire';
                if (!v.contains('@')) return 'E-mail invalide';
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _address,
              label: 'Adresse de livraison',
              hint: 'Ex: Parcelles Assainies U24',
              prefixIcon: const Icon(LucideIcons.mapPin, size: 18),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Position GPS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (_latitude != null && _longitude != null)
                            ? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                            : 'Aucune position GPS',
                        style: TextStyle(
                          color: (_latitude != null) ? AppColors.brandGreenDark : AppColors.mutedText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _gpsLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton.filled(
                        onPressed: _captureGPSLocation,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.brandGreen.withValues(alpha: 0.12),
                          foregroundColor: AppColors.brandGreenDark,
                        ),
                        icon: const Icon(LucideIcons.mapPin, size: 18),
                        tooltip: 'Détecter la position GPS',
                      ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RoleModel>(
                  value: _role,
                  isExpanded: true,
                  hint: const Text('Choisir un rôle'),
                  items: widget.roles
                      .where((r) => r.id != null)
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _role = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Compte Actif',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    activeThumbColor: AppColors.accent,
                    activeTrackColor: AppColors.accent.withValues(alpha: 0.35),
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Enregistrer',
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersPageData {
  final List<AppUserModel> users;
  final List<RoleModel> roles;

  const _UsersPageData({required this.users, required this.roles});
}
