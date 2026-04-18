import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors - E-commerce vibrant
  static const Color brandGreen = Color(0xFF55D80F);
  static const Color brandGreenDark = Color(0xFF1FAE3C);
  static const Color brandBlue = Color(0xFF55D80F);
  static const Color brandBlueDark = Color(0xFF55D80F);
  static const Color brandSurface = Color(0xFFFDFDFD);

  // Primary & Accent
  static const Color primary = brandGreen;
  static const Color primaryDark = brandGreenDark;
  static const Color accent = brandGreen; // Teal moderne
  static const Color accentLight = brandGreen;

  // Navigation
  static const Color navBackground = Colors.white;
  static const Color navInactive = Color(0xFF98A2B3);

  // Backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceElevated = Color(0xFFFEFEFE);
  static const Color border = Color(0xFFE7ECF2);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Text
  static const Color text = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF374151);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // Status Colors
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFF22C55E);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // E-commerce specific
  static const Color sale = Color(0xFFFF6B6B);
  static const Color discount = Color(0xFFFFB800);
  static const Color featured = Color(0xFF8B5CF6);
  static const Color newBadge = Color(0xFF10B981);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [brandGreen, brandGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF55D80F), Color(0xFF1FAE3C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1F2937), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 30,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
