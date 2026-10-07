import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../components/app_list_tile.dart';
import '../components/app_dialog.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          width: AppSpacing.sidebarWidth,
          color: AppColors.sidebarBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile section
              _buildProfileHeader(context, appState),
              const Divider(),
              // Navigation
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSidebarSection(
                        title: 'Navigation',
                        children: [
                          AppListTile(
                            title: 'S3 Buckets',
                            icon: Icons.storage_outlined,
                            isSelected: appState.selectedSection == AppSection.s3Browser,
                            onTap: () => appState.selectSection(AppSection.s3Browser),
                          ),
                          AppListTile(
                            title: 'CloudFront',
                            icon: Icons.language_outlined,
                            isSelected: appState.selectedSection == AppSection.cloudFront,
                            onTap: () => appState.selectSection(AppSection.cloudFront),
                          ),
                          AppListTile(
                            title: 'Activity',
                            icon: Icons.history,
                            isSelected: appState.selectedSection == AppSection.activity,
                            onTap: () => appState.selectSection(AppSection.activity),
                            trailing: appState.runningTasks.isEmpty
                                ? null
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${appState.runningTasks.length}',
                                      style: AppTypography.smallMedium.copyWith(color: AppColors.textInverse),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      if (appState.selectedSection == AppSection.s3Browser) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppSidebarSection(
                          title: 'Buckets',
                          children: appState.buckets.isEmpty
                              ? [
                                  const Padding(
                                    padding: EdgeInsets.all(AppSpacing.lg),
                                    child: Text(
                                      'No buckets loaded',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                ]
                              : appState.buckets.map((bucket) {
                                  final isSelected =
                                      appState.selectedBucket?.name == bucket.name;
                                  return AppListTile(
                                    title: bucket.name,
                                    icon: Icons.folder_outlined,
                                    isActive: isSelected,
                                    onTap: () {
                                      appState.selectSection(AppSection.s3Browser);
                                      appState.selectBucket(bucket);
                                    },
                                  );
                                }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Bottom actions, set apart from the bucket list as a card
              Container(
                margin: const EdgeInsets.all(AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    AppListTile(
                      title: 'Settings',
                      icon: Icons.settings_outlined,
                      isSelected: appState.selectedSection == AppSection.settings,
                      onTap: () => appState.selectSection(AppSection.settings),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppListTile(
                      title: 'Logout',
                      icon: Icons.logout_outlined,
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => const AppConfirmDialog(
                            title: 'Logout',
                            message: 'Are you sure you want to logout?',
                            confirmLabel: 'Logout',
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          context.read<AppState>().logout();
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, AppState appState) {
    final profile = appState.currentProfile;
    if (profile == null) return const SizedBox.shrink();

    final initials = profile.name.isNotEmpty
        ? profile.name[0].toUpperCase()
        : 'P';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: AppTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.credentials.region,
                  style: AppTypography.small,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
