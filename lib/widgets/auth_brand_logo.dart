import 'package:flutter/material.dart';

import '../utils/constants/app_colors.dart';

class AuthBrandLogo extends StatelessWidget {
  final double size;
  final String assetPath;

  const AuthBrandLogo({
    super.key,
    this.size = 180,
    this.assetPath = 'assets/images/logo.png',
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandGreen, AppColors.brandBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.22),
          ),
          alignment: Alignment.center,
          child: Text(
            'GD',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
        );
      },
    );
  }
}
