import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final bool isSelected;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final EdgeInsets? padding;

  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.isSelected = false,
    this.isActive = false,
    this.onTap,
    this.onDoubleTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppColors.selectionBlueLight
        : isActive
            ? AppColors.sidebarSelected
            : Colors.transparent;

    final textColor = isSelected ? AppColors.selectionBlue : AppColors.textPrimary;
    final iconColor = isSelected
        ? AppColors.selectionBlue
        : icon != null
            ? AppColors.textSecondary
            : null;

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: ListTile(
          dense: true,
          contentPadding: padding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          leading: icon != null
              ? Icon(icon, size: 18, color: iconColor)
              : null,
          title: Text(
            title,
            style: AppTypography.body.copyWith(
              color: textColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: AppTypography.caption,
                )
              : null,
          trailing: trailing,
          onTap: onTap,
          hoverColor: AppColors.sidebarHover,
        ),
      ),
    );
  }
}

class AppSidebarSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const AppSidebarSection({
    super.key,
    this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              title!.toUpperCase(),
              style: AppTypography.smallMedium.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ...children,
      ],
    );
  }
}
