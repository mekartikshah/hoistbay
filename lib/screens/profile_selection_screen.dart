import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/aws_profile.dart';
import '../providers/app_state.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../components/app_button.dart';
import '../components/app_dialog.dart';
import '../components/app_progress.dart';
import 'profile_editor_screen.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  List<AwsProfile> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    final profiles = await ProfileService.loadProfiles();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectProfile(AwsProfile profile) async {
    try {
      await ProfileService.setCurrentProfile(profile.id);
      await ProfileService.updateProfileLastUsed(profile.id);

      if (mounted) {
        final appState = context.read<AppState>();
        appState.setCurrentProfile(profile);
        await appState.login(profile.credentials);

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteProfile(AwsProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmDialog(
        title: 'Delete Profile',
        message: 'Are you sure you want to delete "${profile.name}"?',
        confirmLabel: 'Delete',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      await ProfileService.deleteProfile(profile.id);
      _loadProfiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 320,
            color: AppColors.sidebarBackground,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'AWS Profiles',
                        style: AppTypography.headline,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: AppCircularProgress())
                      : _profiles.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.person_off_outlined,
                              title: 'No profiles yet',
                              subtitle: 'Click + to add your first profile',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                              itemCount: _profiles.length,
                              itemBuilder: (context, index) {
                                final profile = _profiles[index];
                                return _ProfileCard(
                                  profile: profile,
                                  onConnect: () => _selectProfile(profile),
                                  onEdit: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileEditorScreen(profile: profile),
                                      ),
                                    ).then((_) => _loadProfiles());
                                  },
                                  onDelete: () => _deleteProfile(profile),
                                );
                              },
                            ),
                ),
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Add New Profile',
                      icon: Icons.add,
                      variant: AppButtonVariant.primary,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileEditorScreen(),
                          ),
                        ).then((_) => _loadProfiles());
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.cloud_outlined,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Hoistbay',
                      style: AppTypography.display,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Select a profile to connect to your Amazon S3 buckets',
                      style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                    ),
                    if (_profiles.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Choose from ${_profiles.length} saved profile${_profiles.length != 1 ? 's' : ''}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AwsProfile profile;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProfileCard({
    required this.profile,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initials = profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'P';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: InkWell(
        onTap: onConnect,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 16,
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
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.credentials.region,
                      style: AppTypography.caption,
                    ),
                    Text(
                      'Last used: ${_formatDate(profile.lastUsed)}',
                      style: AppTypography.small,
                    ),
                  ],
                ),
              ),
              AppButton(
                label: 'Connect',
                variant: AppButtonVariant.primary,
                onPressed: onConnect,
              ),
              const SizedBox(width: AppSpacing.sm),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text('Edit', style: AppTypography.body),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('Delete', style: AppTypography.body.copyWith(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Just now';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
