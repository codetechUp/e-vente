import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_user_model.dart';
import '../models/role_model.dart';
import '../services/app_users_service.dart';
import '../services/roles_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class UsersManagementView extends StatefulWidget {
  const UsersManagementView({super.key});

  @override
  State<UsersManagementView> createState() => _UsersManagementViewState();
}

class _UsersManagementViewState extends State<UsersManagementView> {
  final _usersService = AppUsersService();
  final _rolesService = RolesService();

  late Future<_UsersPageData> _future;

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
    });
  }

  Future<void> _showEditUserSheet(
    AppUserModel user,
    List<RoleModel> roles,
  ) async {
    if (kDebugMode) {
      debugPrint(
        '[UsersManagementView] open edit user id=${user.id} email=${user.email} roleId=${user.roleId} active=${user.isActive}',
      );
    }

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditUserSheet(
        user: user,
        roles: roles,
        onSave: (patch) async {
          if (user.id == null) return;
          if (kDebugMode) {
            debugPrint(
              '[UsersManagementView] saving user id=${user.id} patch=$patch',
            );
          }
          await _usersService.updateById(user.id!, patch);
          if (kDebugMode) {
            debugPrint('[UsersManagementView] save success user id=${user.id}');
          }
        },
      ),
    );

    if (updated == true) {
      await _reload();
    }
  }

  Future<void> _toggleActive(AppUserModel user, bool value) async {
    if (user.id == null) return;

    try {
      if (kDebugMode) {
        debugPrint(
          '[UsersManagementView] toggle active user id=${user.id} email=${user.email} value=$value',
        );
      }
      await _usersService.updateById(user.id!, {'is_active': value});
      if (kDebugMode) {
        debugPrint(
          '[UsersManagementView] toggle active success user id=${user.id}',
        );
      }
      await _reload();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[UsersManagementView] toggle active error user id=${user.id} error=$e',
        );
      }
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
        title: const Text('Utilisateurs'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
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
                padding: const EdgeInsets.all(AppSizes.padding),
                child: Text('Erreur: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const SizedBox.shrink();
          }

          final rolesById = <int, RoleModel>{
            for (final r in data.roles)
              if (r.id != null) r.id!: r,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.padding,
              12,
              AppSizes.padding,
              24,
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
                            'Comptes',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${data.users.length} utilisateur(s)',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Les utilisateurs créent leur compte depuis l’écran de connexion. Ensuite tu peux modifier leur rôle et leur statut ici.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Signup utilisateur',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...data.users.map((u) {
                final roleName = u.roleId == null
                    ? 'Sans rôle'
                    : (rolesById[u.roleId!]?.name ?? 'Rôle #${u.roleId}');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _UserTile(
                    user: u,
                    roleName: roleName,
                    onToggle: (v) => _toggleActive(u, v),
                    onEdit: () => _showEditUserSheet(u, data.roles),
                  ),
                );
              }),
              if (data.users.isEmpty)
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
                        Icons.people_outline,
                        size: 48,
                        color: AppColors.mutedText,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Aucun utilisateur',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Les utilisateurs doivent d’abord créer leur compte depuis le signup. L’admin pourra ensuite modifier leur rôle et leur statut ici.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
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

class _UsersPageData {
  final List<AppUserModel> users;
  final List<RoleModel> roles;

  const _UsersPageData({required this.users, required this.roles});
}

class _UserTile extends StatelessWidget {
  final AppUserModel user;
  final String roleName;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  const _UserTile({
    required this.user,
    required this.roleName,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final active = user.isActive;

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
              color: active
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.person,
              color: active ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user.name == null || user.name!.trim().isEmpty)
                      ? user.email
                      : user.name!,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    roleName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                color: AppColors.mutedText,
                tooltip: 'Modifier',
              ),
              Text(
                active ? 'Actif' : 'Inactif',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: active ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
    );
  }
}

class _EditUserSheet extends StatefulWidget {
  final AppUserModel user;
  final List<RoleModel> roles;
  final Future<void> Function(Map<String, dynamic> patch) onSave;

  const _EditUserSheet({
    required this.user,
    required this.roles,
    required this.onSave,
  });

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  RoleModel? _role;
  late bool _isActive;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name ?? '');
    _email = TextEditingController(text: widget.user.email);
    _phone = TextEditingController(text: widget.user.phone ?? '');
    _isActive = widget.user.isActive;
    _role = widget.roles.firstWhere(
      (r) => r.id != null && r.id == widget.user.roleId,
      orElse: () =>
          widget.roles.isEmpty ? const RoleModel(name: '') : widget.roles.first,
    );
    if (_role?.id == null) {
      _role = null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email obligatoire';
    if (!v.contains('@')) return 'Email invalide';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      final patch = <String, dynamic>{
        'name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'role_id': _role?.id,
        'is_active': _isActive,
      };

      if (kDebugMode) {
        debugPrint(
          '[EditUserSheet] submit user id=${widget.user.id} currentEmail=${widget.user.email} patch=$patch',
        );
      }

      await widget.onSave(patch);

      if (kDebugMode) {
        debugPrint('[EditUserSheet] submit success user id=${widget.user.id}');
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[EditUserSheet] submit error user id=${widget.user.id} error=$e',
        );
      }
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
                'Modifier utilisateur',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _name,
                label: 'Nom',
                hint: 'Ex: Mamadou',
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _email,
                label: 'Email',
                hint: 'exemple@mail.com',
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _phone,
                label: 'Téléphone',
                hint: 'Ex: +221 77...',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
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
                  child: DropdownButton<RoleModel>(
                    value: _role,
                    isExpanded: true,
                    hint: const Text('Choisir un rôle'),
                    items: widget.roles
                        .where((r) => r.id != null)
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.name)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _role = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Compte actif',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      activeThumbColor: AppColors.accent,
                      activeTrackColor: AppColors.accent.withValues(
                        alpha: 0.35,
                      ),
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Enregistrer',
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
