import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/product_model.dart';
import '../models/promotion_model.dart';
import '../providers/cart_provider.dart';
import '../utils/constants/app_colors.dart';

class PromoNotificationDialog extends StatelessWidget {
  final ProductModel product;
  final PromotionModel promotion;

  const PromoNotificationDialog({
    super.key,
    required this.product,
    required this.promotion,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final quantity = cart.items
        .where((item) => item.product.id == product.id)
        .fold<int>(0, (sum, item) => sum + item.quantity);
    final pct = (promotion.discountPercent ?? 0).toInt();
    final discountedPrice = product.price * (1 - pct / 100);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 24,
      backgroundColor: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Main Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🔥 VENTE FLASH !',
                  style: TextStyle(
                    color: Color(0xFFFF4B4B),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Price Tag area
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} F',
                        style: TextStyle(
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        LucideIcons.arrowRight,
                        size: 16,
                        color: AppColors.brandGreen,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${discountedPrice.toStringAsFixed(0)} F',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brandGreenDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Cart Quantity controller or Add Button
                if (quantity == 0)
                  ElevatedButton.icon(
                    onPressed: () {
                      cart.add(
                        product,
                        quantity: 1,
                        effectivePrice: discountedPrice,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.name} ajouté au panier !'),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                    label: const Text(
                      'Ajouter au panier',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: AppColors.brandGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => cart.decrement(product),
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.brandGreen, size: 36),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => cart.add(
                          product,
                          quantity: 1,
                          effectivePrice: discountedPrice,
                        ),
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.brandGreen, size: 36),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                
                // Close button
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.mutedText,
                  ),
                  child: const Text(
                    'Fermer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          // Floating Product image & discount badge
          Positioned(
            top: -64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // White backing circle
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: (product.imageUrl ?? '').trim().isEmpty
                      ? const Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: AppColors.mutedText,
                        )
                      : Image.network(
                          product.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: AppColors.mutedText,
                          ),
                        ),
                ),

                // Discount Badge on the floating image
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4B4B), Color(0xFFFF8E53)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4B4B).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '-$pct%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
