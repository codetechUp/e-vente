import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../utils/constants/app_strings.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_brand_logo.dart';
import '../widgets/auth_footer_link.dart';

enum RegisterMode { phone, email }

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  
  RegisterMode _mode = RegisterMode.phone;
  bool _otpSent = false;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _adresseController = TextEditingController();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _referrerController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _adresseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _referrerController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      referrerId: _referrerController.text.trim().isEmpty ? null : _referrerController.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      if (auth.user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Compte créé. Connecte-toi maintenant avec ton email et ton mot de passe.',
            ),
          ),
        );
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        return;
      }

      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      return;
    }

    final error = auth.error ?? 'Création de compte échouée.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final phone = '+221${_phoneController.text.trim().replaceAll(' ', '')}';
    
    final ok = await auth.sendOtp(phone: phone);

    if (!mounted) return;

    if (ok) {
      setState(() {
        _otpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code envoyé par SMS')),
      );
    } else {
      final error = auth.error ?? 'Échec de l\'envoi du code.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _verifyOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final phone = '+221${_phoneController.text.trim().replaceAll(' ', '')}';
    final token = _otpController.text.trim();

    final ok = await auth.verifyOtp(
      phone: phone, 
      token: token,
      name: _nameController.text.trim(),
      adresse: _adresseController.text.trim(),
      referrerId: _referrerController.text.trim().isEmpty ? null : _referrerController.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      return;
    }

    final error = auth.error ?? 'Code incorrect ou expiré.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  String? _emailValidator(String? value) {
    if (_mode != RegisterMode.email) return null;
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email obligatoire';
    if (!v.contains('@')) return 'Email invalide';
    return null;
  }

  String? _passwordValidator(String? value) {
    if (_mode != RegisterMode.email) return null;
    final v = value ?? '';
    if (v.isEmpty) return 'Mot de passe obligatoire';
    if (v.length < 6) return 'Minimum 6 caractères';
    return null;
  }

  String? _confirmValidator(String? value) {
    if (_mode != RegisterMode.email) return null;
    final v = value ?? '';
    if (v.isEmpty) return 'Confirmation obligatoire';
    if (v != _passwordController.text) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    if (_mode != RegisterMode.phone) return null;
    final v = value?.trim().replaceAll(' ', '') ?? '';
    if (v.isEmpty) return 'Numéro obligatoire';
    if (v.length != 9) return 'Le numéro doit contenir 9 chiffres';
    if (!v.startsWith('7')) return 'Le numéro doit commencer par 7';
    return null;
  }

  String? _otpValidator(String? value) {
    if (_mode != RegisterMode.phone || !_otpSent) return null;
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Code obligatoire';
    if (v.length != 6) return 'Le code doit contenir 6 chiffres';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 850;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: !isDesktop,
        bottom: !isDesktop,
        child: Form(
          key: _formKey,
          child: isDesktop
              ? Row(
                  children: [
                    Expanded(
                      flex: 11,
                      child: _buildShowcasePanel(context),
                    ),
                    Expanded(
                      flex: 9,
                      child: _buildFormPanel(context, loading),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.padding,
                    vertical: AppSizes.paddingLg,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          const Center(child: AuthBrandLogo(size: 160)),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.appName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.mutedText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'INSCRIPTION',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.text,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(AppSizes.paddingLg),
                            decoration: BoxDecoration(
                              color: AppColors.brandSurface,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildModeSelector(),
                                const SizedBox(height: 24),
                                if (_mode == RegisterMode.phone) _buildPhoneForm(loading),
                                if (_mode == RegisterMode.email) _buildEmailForm(loading),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildShowcasePanel(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF071F02), // Deep forest dark green
            Color(0xFF0F3E04), // Darker green
            Color(0xFF1E6C0A), // Medium green
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Subtle background decoration or grids
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: GridPaper(
                color: Colors.white,
                divisions: 1,
                subdivisions: 1,
                interval: 40,
              ),
            ),
          ),
          // Soft glowing background circles
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.12),
              ),
            ),
          ),
          // Brand & feature content (Scrollable to prevent overflow)
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo/Brand Name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        AppStrings.appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  // Title and Subtitle
                  Text(
                    'Rejoignez notre réseau de commerce moderne',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Créez votre compte en quelques instants, scannez le code d’un commercial si vous en avez un, et commencez à passer vos commandes.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Feature list (dynamic visual elements)
                  _buildFeatureBadge(
                    Icons.person_add_alt_1_outlined,
                    'Création de Compte Simple',
                    'Inscrivez-vous via SMS OTP ou adresse e-mail au choix.',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureBadge(
                    Icons.qr_code_scanner_outlined,
                    'Système de Parrainage Direct',
                    'Liez votre compte à un commercial via son QR Code.',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureBadge(
                    Icons.local_shipping_outlined,
                    'Livraison & Suivi Express',
                    'Indiquez votre adresse de livraison pour vos commandes.',
                  ),
                  const SizedBox(height: 48),
                  // Footer
                  Text(
                    '© 2026 ${AppStrings.appName}. Tous droits réservés.',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel(BuildContext context, bool loading) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 40,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo centered
              const Center(child: AuthBrandLogo(size: 130)),
              const SizedBox(height: 12),
              Text(
                'INSCRIPTION',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModeSelector(),
                    const SizedBox(height: 24),
                    if (_mode == RegisterMode.phone) _buildPhoneForm(loading),
                    if (_mode == RegisterMode.email) _buildEmailForm(loading),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _mode = RegisterMode.phone;
                  _otpSent = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _mode == RegisterMode.phone ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _mode == RegisterMode.phone ? AppColors.cardShadow : null,
                ),
                child: Center(
                  child: Text(
                    'Téléphone',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _mode == RegisterMode.phone ? Colors.white : AppColors.mutedText,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _mode = RegisterMode.email;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _mode == RegisterMode.email ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _mode == RegisterMode.email ? AppColors.cardShadow : null,
                ),
                child: Center(
                  child: Text(
                    'E-mail',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _mode == RegisterMode.email ? Colors.white : AppColors.mutedText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneForm(bool loading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _otpSent ? 'Vérification' : 'Créer un compte',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _otpSent 
            ? 'Entre le code reçu par SMS.' 
            : 'Rejoins-nous avec ton numéro de téléphone.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 20),
        AppTextField(
          controller: _nameController,
          label: 'Nom complet *',
          keyboardType: TextInputType.name,
          validator: (v) {
             if (_mode != RegisterMode.phone) return null;
             return v?.trim().isEmpty == true ? 'Nom obligatoire' : null;
          },
          enabled: !_otpSent,
          prefixIcon: const Icon(Icons.person_outline),
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _adresseController,
          label: 'Adresse de livraison *',
          keyboardType: TextInputType.streetAddress,
          validator: (v) {
             if (_mode != RegisterMode.phone) return null;
             return v?.trim().isEmpty == true ? 'Adresse obligatoire' : null;
          },
          enabled: !_otpSent,
          prefixIcon: const Icon(Icons.location_on_outlined),
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _phoneController,
          label: 'Numéro de téléphone *',
          keyboardType: TextInputType.phone,
          validator: _phoneValidator,
          enabled: !_otpSent,
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+221',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.border,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        if (!_otpSent) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _referrerController,
                  label: 'ID Commercial (Optionnel)',
                  keyboardType: TextInputType.text,
                  prefixIcon: const Icon(Icons.qr_code_scanner_outlined),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _scanReferrerQrCode,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(14),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
              ),
            ],
          ),
        ],
        if (_otpSent) ...[
          const SizedBox(height: 14),
          AppTextField(
            controller: _otpController,
            label: 'Code à 6 chiffres *',
            keyboardType: TextInputType.number,
            validator: _otpValidator,
            prefixIcon: const Icon(Icons.password_outlined),
          ),
        ],
        const SizedBox(height: 18),
        AppButton(
          label: _otpSent ? 'Vérifier et créer' : 'Envoyer le code',
          loading: loading,
          onPressed: _otpSent ? _verifyOtp : _sendOtp,
        ),
        if (_otpSent) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _otpSent = false;
                  _otpController.clear();
                });
              },
              child: Text(
                'Modifier le numéro',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          AuthFooterLink(
            text: 'Déjà un compte ? ',
            linkText: 'Se connecter',
            onTap: () {
              Navigator.of(
                context,
              ).pushReplacementNamed(AppRoutes.login);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildEmailForm(bool loading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Créer un compte',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Rejoins-nous et commence à acheter facilement.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 20),
        AppTextField(
          controller: _emailController,
          label: 'E-mail *',
          keyboardType: TextInputType.emailAddress,
          validator: _emailValidator,
          prefixIcon: const Icon(Icons.email_outlined),
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _passwordController,
          label: 'Mot de passe *',
          obscureText: _obscurePassword,
          validator: _passwordValidator,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _confirmController,
          label: 'Confirmer le mot de passe *',
          obscureText: _obscureConfirm,
          validator: _confirmValidator,
          prefixIcon: const Icon(Icons.lock_reset_outlined),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () {
              setState(() => _obscureConfirm = !_obscureConfirm);
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _referrerController,
                label: 'ID Commercial (Optionnel)',
                keyboardType: TextInputType.text,
                prefixIcon: const Icon(Icons.qr_code_scanner_outlined),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _scanReferrerQrCode,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(14),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Créer le compte',
          loading: loading,
          onPressed: _submitEmail,
        ),
        const SizedBox(height: 12),
        AuthFooterLink(
          text: 'Déjà un compte ? ',
          linkText: 'Se connecter',
          onTap: () {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.login);
          },
        ),
      ],
    );
  }

  Future<void> _scanReferrerQrCode() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner, color: AppColors.primary),
              SizedBox(width: 8),
              Text('QR Code Commercial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scannez le QR Code de votre commercial ou collez son identifiant unique (UUID) ci-dessous.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 40, color: AppColors.mutedText),
                    SizedBox(height: 8),
                    Text('Simulateur Caméra Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Prêt à détecter le code QR', style: TextStyle(color: AppColors.mutedText, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: 'Coller l\'identifiant (UUID)',
                  hintText: 'xxxx-xxxx-xxxx-xxxx',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: AppColors.mutedText)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _referrerController.text = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commercial associé avec succès !'), backgroundColor: AppColors.success),
      );
    }
  }
}
