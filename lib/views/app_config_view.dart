import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/app_config_model.dart';
import '../services/app_config_service.dart';
import '../utils/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MAIN CONFIGURATION VIEW
// ─────────────────────────────────────────────────────────────────────────────

class AppConfigView extends StatefulWidget {
  const AppConfigView({super.key});

  @override
  State<AppConfigView> createState() => _AppConfigViewState();
}

class _AppConfigViewState extends State<AppConfigView> {
  final _service = AppConfigService();
  late Future<AppConfigModel> _future;

  // Form controllers
  final _storeNameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _displayPhoneCtrl = TextEditingController();

  // WhatsApp numbers (max 2)
  final _waCtrl1 = TextEditingController();
  final _waCtrl2 = TextEditingController();

  // Call numbers (max 2)
  final _callCtrl1 = TextEditingController();
  final _callCtrl2 = TextEditingController();

  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _future = _service.getConfig();
    _future.then(_populate);

    // Listeners to trigger live preview rebuilds
    _storeNameCtrl.addListener(_onFieldChanged);
    _locationCtrl.addListener(_onFieldChanged);
    _displayPhoneCtrl.addListener(_onFieldChanged);
    _waCtrl1.addListener(_onFieldChanged);
    _waCtrl2.addListener(_onFieldChanged);
    _callCtrl1.addListener(_onFieldChanged);
    _callCtrl2.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _populate(AppConfigModel cfg) {
    if (!mounted) return;
    _storeNameCtrl.text = cfg.storeName;
    _locationCtrl.text = cfg.location;
    _displayPhoneCtrl.text = cfg.displayPhone;
    _waCtrl1.text = cfg.whatsappNumbers.isNotEmpty ? cfg.whatsappNumbers[0] : '';
    _waCtrl2.text = cfg.whatsappNumbers.length > 1 ? cfg.whatsappNumbers[1] : '';
    _callCtrl1.text = cfg.callNumbers.isNotEmpty ? cfg.callNumbers[0] : '';
    _callCtrl2.text = cfg.callNumbers.length > 1 ? cfg.callNumbers[1] : '';
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _locationCtrl.dispose();
    _displayPhoneCtrl.dispose();
    _waCtrl1.dispose();
    _waCtrl2.dispose();
    _callCtrl1.dispose();
    _callCtrl2.dispose();
    super.dispose();
  }

  List<String> _parseNumbers(TextEditingController c1, TextEditingController c2) {
    final nums = <String>[];
    final v1 = c1.text.trim();
    final v2 = c2.text.trim();
    if (v1.isNotEmpty) nums.add(v1);
    if (v2.isNotEmpty) nums.add(v2);
    return nums;
  }

  Future<void> _save() async {
    final storeName = _storeNameCtrl.text.trim();
    if (storeName.isEmpty) {
      _snack('Le nom de la boutique est requis.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final cfg = AppConfigModel(
        storeName: storeName,
        location: _locationCtrl.text.trim(),
        displayPhone: _displayPhoneCtrl.text.trim(),
        whatsappNumbers: _parseNumbers(_waCtrl1, _waCtrl2),
        callNumbers: _parseNumbers(_callCtrl1, _callCtrl2),
      );
      await _service.saveConfig(cfg);
      _snack('Configuration enregistrée avec succès ✓');
    } catch (e) {
      _snack('Erreur lors de la sauvegarde : $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waNumbers = _parseNumbers(_waCtrl1, _waCtrl2);
    final callNumbers = _parseNumbers(_callCtrl1, _callCtrl2);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar Premium ────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            expandedHeight: 110,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: AppColors.text,
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
              title: const Text(
                'Configuration Boutique',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.text,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.08),
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.border),
            ),
          ),

          // ── Content ────────────────────────────────────────────────────────
          FutureBuilder<AppConfigModel>(
            future: _future,
            builder: (context, snapshot) {
              if (!_loaded &&
                  snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError && !_loaded) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Erreur: ${snapshot.error}'),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Live preview card displaying mockup of the app client header
                    _LivePreviewCard(
                      storeName: _storeNameCtrl.text,
                      location: _locationCtrl.text,
                      displayPhone: _displayPhoneCtrl.text,
                      whatsappNumbers: waNumbers,
                      callNumbers: callNumbers,
                    ),
                    const SizedBox(height: 28),

                    // ── Section 1: Informations Générales ────────────────────
                    _SectionHeader(
                      icon: Icons.storefront_outlined,
                      color: const Color(0xFF6366F1),
                      title: 'Identité de la Boutique',
                      subtitle: 'Nom, adresse et contact affichés sur la page d\'accueil',
                    ),
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Field(
                            controller: _storeNameCtrl,
                            label: 'Nom de la boutique *',
                            hint: 'Ex: Saliou Kane',
                            icon: Icons.store_outlined,
                            color: const Color(0xFF6366F1),
                          ),
                          const SizedBox(height: 18),
                          _Field(
                            controller: _locationCtrl,
                            label: 'Localisation',
                            hint: 'Ex: Grand Mbao, Dakar',
                            icon: Icons.location_on_outlined,
                            color: const Color(0xFF6366F1),
                          ),
                          const SizedBox(height: 18),
                          _Field(
                            controller: _displayPhoneCtrl,
                            label: 'Numéro affiché',
                            hint: 'Ex: +221 77 999 02 02',
                            icon: Icons.phone_outlined,
                            color: const Color(0xFF6366F1),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Section 2: Canaux de Contact WhatsApp ────────────────
                    _SectionHeader(
                      icon: LucideIcons.messageCircle,
                      color: const Color(0xFF25D366),
                      title: 'Numéros WhatsApp',
                      subtitle: 'Maximum 2 numéros — utilisés pour le chat direct',
                    ),
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Field(
                            controller: _waCtrl1,
                            label: 'WhatsApp n°1 (Principal)',
                            hint: 'Ex: +221779990202',
                            icon: LucideIcons.messageCircle,
                            color: const Color(0xFF25D366),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 18),
                          _Field(
                            controller: _waCtrl2,
                            label: 'WhatsApp n°2 (Optionnel)',
                            hint: 'Ex: +221779990203',
                            icon: LucideIcons.messageCircle,
                            color: const Color(0xFF25D366),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _InfoTip(
                      text: 'Le premier numéro configuré servira de contact par défaut pour la redirection rapide. S\'il y a deux numéros, une modal de choix s\'affiche.',
                    ),
                    const SizedBox(height: 28),

                    // ── Section 3: Numéros d\'Appel Simple ───────────────────
                    _SectionHeader(
                      icon: Icons.call_outlined,
                      color: AppColors.primary,
                      title: 'Numéros d\'Appel Direct',
                      subtitle: 'Maximum 2 numéros — pour les appels classiques',
                    ),
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Field(
                            controller: _callCtrl1,
                            label: 'Appel n°1 (Principal)',
                            hint: 'Ex: +221779990202',
                            icon: Icons.call_outlined,
                            color: AppColors.primary,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 18),
                          _Field(
                            controller: _callCtrl2,
                            label: 'Appel n°2 (Optionnel)',
                            hint: 'Ex: +221779990203',
                            icon: Icons.call_outlined,
                            color: AppColors.primary,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _InfoTip(
                      text: 'Ces numéros permettent aux clients de vous téléphoner directement. Configurer les numéros au format international avec indicatif.',
                    ),
                    const SizedBox(height: 40),

                    // Enregistrer Button
                    _SaveButton(loading: _saving, onTap: _save),
                    const SizedBox(height: 24),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM SUB-WIDGETS & PREVIEWS
// ─────────────────────────────────────────────────────────────────────────────

class _LivePreviewCard extends StatelessWidget {
  final String storeName;
  final String location;
  final String displayPhone;
  final List<String> whatsappNumbers;
  final List<String> callNumbers;

  const _LivePreviewCard({
    required this.storeName,
    required this.location,
    required this.displayPhone,
    required this.whatsappNumbers,
    required this.callNumbers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)], // Modern slate-grey premium colors
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 12),
                    SizedBox(width: 6),
                    Text(
                      'APERÇU EN DIRECT (CLIENT)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.smartphone_rounded, color: Colors.white38, size: 18),
            ],
          ),
          const SizedBox(height: 20),

          // Header layout preview
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName.trim().isNotEmpty ? storeName : 'Ma Boutique',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (displayPhone.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        displayPhone,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (location.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Contact button mockup
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.messageCircle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 12),

          // Channels description
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PreviewChannelBadge(
                icon: LucideIcons.messageCircle,
                color: const Color(0xFF25D366),
                label: '${whatsappNumbers.length} WhatsApp',
                active: whatsappNumbers.isNotEmpty,
              ),
              _PreviewChannelBadge(
                icon: Icons.call,
                color: AppColors.primary,
                label: '${callNumbers.length} Appel(s)',
                active: callNumbers.isNotEmpty,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewChannelBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool active;

  const _PreviewChannelBadge({
    required this.icon,
    required this.color,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: active ? color : Colors.white24, size: 14),
        const SizedBox(width: 6),
        Text(
          active ? label : 'Non configuré',
          style: TextStyle(
            color: active ? Colors.white70 : Colors.white30,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color? color;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.color,
    this.keyboardType,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    final activeColor = widget.color ?? const Color(0xFF6366F1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _isFocused ? activeColor : Colors.grey.shade700,
              letterSpacing: 0.1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isFocused ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isFocused ? activeColor : Colors.grey.shade300,
              width: _isFocused ? 1.5 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: _isFocused ? activeColor : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: widget.keyboardType,
                  onChanged: (val) {
                    setState(() {});
                  },
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (hasText)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton(
                    icon: Icon(Icons.cancel_rounded, size: 16, color: Colors.grey.shade400),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() {});
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoTip extends StatelessWidget {
  final String text;

  const _InfoTip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _SaveButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: loading
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: loading ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Enregistrer la configuration',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
