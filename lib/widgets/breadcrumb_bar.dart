import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(
              bottom: BorderSide(color: AppColors.borderLight),
            ),
          ),
          child: Row(
            children: [
              if (appState.breadcrumbs.length > 1)
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                    onTap: () => appState.navigateUp(),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < appState.breadcrumbs.length; i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        _BreadcrumbItem(
                          label: appState.breadcrumbs[i],
                          isRoot: i == 0,
                          isActive: i == appState.breadcrumbs.length - 1,
                          onTap: i < appState.breadcrumbs.length - 1
                              ? () => appState.navigateToBreadcrumb(i)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  final String label;
  final bool isRoot;
  final bool isActive;
  final VoidCallback? onTap;

  const _BreadcrumbItem({
    required this.label,
    this.isRoot = false,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.selectionBlueLight : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRoot ? Icons.storage : Icons.folder_outlined,
                size: 14,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
