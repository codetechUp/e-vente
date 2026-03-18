import 'package:flutter/material.dart';

import '../utils/constants/app_colors.dart';

class BadgeIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final int? badge;

  const BadgeIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
        ),
        if (badge != null && badge! > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$badge',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}
