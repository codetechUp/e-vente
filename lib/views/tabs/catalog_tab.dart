import 'package:flutter/material.dart';

import '../../utils/constants/app_colors.dart';
import '../../utils/constants/app_sizes.dart';
import '../../widgets/badge_icon_button.dart';

class CatalogTab extends StatelessWidget {
  const CatalogTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.padding,
              10,
              AppSizes.padding,
              10,
            ),
            child: Row(
              children: const [
                Expanded(child: _SearchBar()),
                SizedBox(width: 10),
                BadgeIconButton(icon: Icons.shopping_cart_outlined, badge: 7),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 110),
                    children: const [
                      _CategoryChip(icon: Icons.storefront, label: 'Tout', active: true),
                      _CategoryChip(icon: Icons.local_fire_department, label: 'En promo'),
                      _CategoryChip(icon: Icons.local_drink, label: 'Boite de Jus'),
                      _CategoryChip(icon: Icons.coffee, label: 'Café/Thé'),
                      _CategoryChip(icon: Icons.lunch_dining, label: 'Cuisine'),
                      _CategoryChip(icon: Icons.soap, label: 'Cosmétique'),
                      _CategoryChip(icon: Icons.local_drink_outlined, label: 'Can Jus'),
                      _CategoryChip(icon: Icons.local_bar_outlined, label: 'Soda'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      0,
                      AppSizes.padding,
                      110,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      return const _CatalogProductCard();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.mutedText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rechercher un produit',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const Icon(Icons.qr_code_scanner, color: AppColors.mutedText),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _CategoryChip({
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.border,
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? AppColors.accent : AppColors.mutedText),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: active ? AppColors.text : AppColors.mutedText,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogProductCard extends StatelessWidget {
  const _CatalogProductCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSizes.radius),
              ),
              child: const Center(
                child: Icon(Icons.image_outlined, size: 40, color: AppColors.mutedText),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Huile Seni 5L x4',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '21 500 F',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '+1 pts',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.add, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
