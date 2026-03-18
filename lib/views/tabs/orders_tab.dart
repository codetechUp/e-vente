import 'package:flutter/material.dart';

import '../../utils/constants/app_colors.dart';
import '../../utils/constants/app_sizes.dart';
import '../../widgets/app_button.dart';
import '../../widgets/badge_icon_button.dart';

class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.padding,
          10,
          AppSizes.padding,
          110,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    'Commandes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ),
              const BadgeIconButton(icon: Icons.shopping_cart_outlined, badge: 7),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingLg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Icon(Icons.inventory_2_outlined, size: 58, color: AppColors.mutedText),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Vous n'avez pas encore effectuer de commande !!!",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Merci de visiter notre catalogue pour commander des produits",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 18),
                AppButton(label: 'Voir le catalogue', onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
