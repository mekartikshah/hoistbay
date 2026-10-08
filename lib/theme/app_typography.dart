import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography scale for Hoistbay using system fonts
class AppTypography {
  AppTypography._();

  static const String fontFamily = '.SF Pro Text'; // macOS system font
  static const String fontFamilyFallback = 'Segoe UI'; // Windows fallback

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // Display
  static TextStyle get display => const TextStyle(
    fontSize: 28,
    fontWeight: bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  // Title
  static TextStyle get title => const TextStyle(
    fontSize: 20,
    fontWeight: semibold,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  // Headline
  static TextStyle get headline => const TextStyle(
    fontSize: 17,
    fontWeight: semibold,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  // Body
  static TextStyle get body => const TextStyle(
    fontSize: 15,
    fontWeight: regular,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
  );

  static TextStyle get bodyMedium => const TextStyle(
    fontSize: 15,
    fontWeight: medium,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
  );

  // Caption
  static TextStyle get caption => const TextStyle(
    fontSize: 13,
    fontWeight: regular,
    color: AppColors.textSecondary,
    letterSpacing: 0,
  );

  static TextStyle get captionMedium => const TextStyle(
    fontSize: 13,
    fontWeight: medium,
    color: AppColors.textSecondary,
    letterSpacing: 0,
  );

  // Small
  static TextStyle get small => const TextStyle(
    fontSize: 11,
    fontWeight: regular,
    color: AppColors.textTertiary,
    letterSpacing: 0.1,
  );

  static TextStyle get smallMedium => const TextStyle(
    fontSize: 11,
    fontWeight: medium,
    color: AppColors.textTertiary,
    letterSpacing: 0.1,
  );

  // Button
  static TextStyle get button => const TextStyle(
    fontSize: 14,
    fontWeight: semibold,
    color: AppColors.textInverse,
    letterSpacing: 0,
  );

  static TextStyle get buttonSecondary => const TextStyle(
    fontSize: 14,
    fontWeight: medium,
    color: AppColors.primary,
    letterSpacing: 0,
  );
}
