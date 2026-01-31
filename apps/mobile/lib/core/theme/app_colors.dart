import 'package:flutter/material.dart';

/// PayroPOS Color Palette - Modern Teal & Lavender Theme
/// Based on docs/COLOR_PALETTE.md
class AppColors {
  AppColors._();

  // Primary Colors - Dark Teal
  static const Color primary = Color(0xFF1E454F);        // Primary dark teal (headers/buttons)
  static const Color primaryLight = Color(0xFF2A5761);   // Lighter teal (hover states)
  static const Color primaryDark = Color(0xFF173F49);    // Secondary deep teal (shadow/alt)
  static const Color primaryMuted = Color(0xFF87AC9E);   // Muted teal (icons/soft blocks)

  // Secondary Colors - Blue Grey
  static const Color secondary = Color(0xFF5B7378);      // Muted blue-grey (text/lines)
  static const Color secondaryLight = Color(0xFF7A9499); // Lighter blue-grey
  static const Color secondaryDark = Color(0xFF4A5F63);  // Darker blue-grey

  // Accent Colors
  static const Color accent = Color(0xFFD3C2F8);         // Lavender accent
  static const Color accentLime = Color(0xFFC3F351);     // Lime accent (highlight/CTA underline)
  static const Color accentDark = Color(0xFFB5A4E0);     // Darker lavender

  // Background Colors (Light Theme)
  static const Color background = Color(0xFFCAD6DC);     // Cool light grey/blue background
  static const Color surface = Color(0xFFFFFFFF);        // Pure white (cards/text areas)
  static const Color surfaceVariant = Color(0xFFF5F5F6); // Off-white (soft UI white)
  static const Color surfaceTint = Color(0xFFE3E4EE);    // Light lavender/grey (UI tint)

  // Background Colors (Dark Theme)
  static const Color backgroundDark = Color(0xFF0F172A); // Dark mode background
  static const Color surfaceDark = Color(0xFF1E293B);    // Dark mode cards, dialogs

  // Text Colors
  static const Color textPrimary = Color(0xFF1E454F);    // Headings, body text (matches primary)
  static const Color textSecondary = Color(0xFF5B7378);  // Labels, captions (matches secondary)
  static const Color textTertiary = Color(0xFF87AC9E);   // Placeholders, hints (muted teal)
  static const Color textOnPrimary = Color(0xFFFFFFFF);  // Text on primary color
  static const Color textLight = Color(0xFFFFFFFF);      // White text (alias)
  static const Color textMuted = Color(0xFF87AC9E);      // Muted text (alias)

  // Semantic/Status Colors
  static const Color success = Color(0xFF059669);        // Paid, Complete, Confirmed
  static const Color warning = Color(0xFFD97706);        // Pending, Partial, Alert
  static const Color error = Color(0xFFDC2626);          // Failed, Overdue, Danger
  static const Color info = Color(0xFF0284C7);           // Information, Tips, Links

  // Status Background Colors (for badges/chips)
  static const Color successBg = Color(0xFFD1FAE5);      // Success background
  static const Color warningBg = Color(0xFFFEF3C7);      // Warning background
  static const Color errorBg = Color(0xFFFEE2E2);        // Error background
  static const Color infoBg = Color(0xFFE0F2FE);         // Info background

  // Border Colors
  static const Color border = Color(0xFFE3E4EE);         // Light theme border (matches surfaceTint)
  static const Color borderDark = Color(0xFF5B7378);     // Dark theme border

  // Additional UI Colors
  static const Color divider = Color(0xFFE3E4EE);
  static const Color shadow = Color(0x1A173F49);         // 10% primary dark
  static const Color overlay = Color(0x80173F49);        // 50% primary dark

  // Credit Status Colors (for customer credit tracking)
  static const Color creditGood = Color(0xFF059669);     // Good standing (no balance)
  static const Color creditWarning = Color(0xFFD97706);  // Near limit / partial payment
  static const Color creditBad = Color(0xFFDC2626);      // Over limit / overdue

  // Category Colors (for product categories)
  static const Color categoryTeal = Color(0xFF1E454F);
  static const Color categoryBlue = Color(0xFF0284C7);
  static const Color categoryPurple = Color(0xFF7C3AED);
  static const Color categoryPink = Color(0xFFDB2777);
  static const Color categoryRed = Color(0xFFDC2626);
  static const Color categoryAmber = Color(0xFFD97706);
  static const Color categoryGreen = Color(0xFF059669);
  static const Color categorySlate = Color(0xFF5B7378);

  // List of category colors for easy iteration
  static const List<Color> categoryColors = [
    categoryTeal,
    categoryBlue,
    categoryPurple,
    categoryPink,
    categoryRed,
    categoryAmber,
    categoryGreen,
    categorySlate,
  ];

  // Role-based colors
  static const Color roleOwner = Color(0xFF1E454F);      // Owner badge color
  static const Color roleStaff = Color(0xFF87AC9E);      // Staff badge color
  static const Color roleAdmin = Color(0xFFD3C2F8);      // Admin badge color (lavender)
}
