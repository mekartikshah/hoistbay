import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/app_dialog.dart';
import '../components/app_input.dart';
import '../models/default_http_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          color: AppColors.background,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings', style: AppTypography.display),
                    const SizedBox(height: AppSpacing.xxl),
                    // Profile section
                    _buildProfileSection(context, appState),
                    const SizedBox(height: AppSpacing.xxl),
                    // Default Headers section
                    _buildHeadersSection(context, appState),
                    const SizedBox(height: AppSpacing.xxl),
                    // About section
                    _buildAboutSection(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileSection(BuildContext context, AppState appState) {
    final profile = appState.currentProfile;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCardHeader(
            title: 'Profile',
            subtitle: 'Your current AWS connection details',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (profile != null) ...[
            _buildInfoRow('Name', profile.name),
            _buildInfoRow('Region', profile.credentials.region),
            _buildInfoRow('Access Key', '${profile.credentials.accessKeyId.substring(0, 4)}****'),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              AppButton(
                label: 'Switch Profile',
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  appState.logout();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                label: 'Manage Profiles',
                variant: AppButtonVariant.text,
                onPressed: () {
                  appState.logout();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeadersSection(BuildContext context, AppState appState) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppCardHeader(
                  title: 'Default HTTP Headers',
                  subtitle: 'Headers applied automatically during uploads',
                ),
              ),
              AppButton(
                label: 'Add Header',
                icon: Icons.add,
                variant: AppButtonVariant.primary,
                onPressed: () => _showHeaderEditor(context, appState),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (appState.defaultHeaders.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.http, color: AppColors.textTertiary, size: 32),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'No default headers configured',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: appState.defaultHeaders.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final header = appState.defaultHeaders[index];
                return _buildHeaderRow(context, appState, header);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, AppState appState, DefaultHttpHeader header) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(header.bucket, style: AppTypography.bodyMedium),
                Text('Mask: ${header.fileMask}', style: AppTypography.caption),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(header.headerName, style: AppTypography.bodyMedium),
                Text(header.headerValue, style: AppTypography.caption),
              ],
            ),
          ),
          Row(
            children: [
              AppIconButton(
                icon: Icons.edit,
                tooltip: 'Edit',
                onPressed: () => _showHeaderEditor(context, appState, header),
              ),
              AppIconButton(
                icon: Icons.delete,
                tooltip: 'Delete',
                color: AppColors.error,
                onPressed: () => _deleteHeader(context, appState, header),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _deleteHeader(BuildContext context, AppState appState, DefaultHttpHeader header) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmDialog(
        title: 'Delete Header',
        message: 'Are you sure you want to delete this header rule?',
        confirmLabel: 'Delete',
        isDestructive: true,
      ),
    );
    if (confirmed == true) {
      final updated = appState.defaultHeaders.where((h) => h.id != header.id).toList();
      await appState.saveDefaultHeaders(updated);
    }
  }

  void _showHeaderEditor(BuildContext context, AppState appState, [DefaultHttpHeader? header]) {
    final isEditing = header != null;
    final buckets = appState.buckets.map((b) => b.name).toList();
    String? selectedBucket = header?.bucket;
    if (selectedBucket != null && selectedBucket.isEmpty) selectedBucket = null;
    if (selectedBucket == null && buckets.isNotEmpty) selectedBucket = buckets.first;

    final fileMaskController = TextEditingController(text: header?.fileMask ?? '');
    final headerNameController = TextEditingController(text: header?.headerName ?? '');
    final headerValueController = TextEditingController(text: header?.headerValue ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AppDialog(
            title: isEditing ? 'Edit Header' : 'Add Header',
            maxWidth: 520,
            content: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (buckets.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: buckets.contains(selectedBucket) ? selectedBucket : buckets.first,
                      decoration: const InputDecoration(labelText: 'Bucket'),
                      items: buckets.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() => selectedBucket = val),
                    )
                  else
                    AppInput(
                      label: 'Bucket',
                      hint: 'Enter bucket name',
                      onChanged: (val) => selectedBucket = val,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: fileMaskController,
                    label: 'File mask (e.g., *.js)',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: headerNameController,
                    label: 'Header (e.g., Content-Type)',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: headerValueController,
                    label: 'Value (e.g., application/javascript)',
                  ),
                ],
              ),
            ),
            actions: [
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              AppButton(
                label: 'Save',
                variant: AppButtonVariant.primary,
                onPressed: () {
                  final newHeader = DefaultHttpHeader(
                    id: isEditing ? header.id : DateTime.now().millisecondsSinceEpoch.toString(),
                    bucket: selectedBucket ?? '',
                    fileMask: fileMaskController.text.trim(),
                    headerName: headerNameController.text.trim(),
                    headerValue: headerValueController.text.trim(),
                  );
                  final updated = List<DefaultHttpHeader>.from(appState.defaultHeaders);
                  if (isEditing) {
                    final index = updated.indexWhere((h) => h.id == header.id);
                    if (index != -1) updated[index] = newHeader;
                  } else {
                    updated.add(newHeader);
                  }
                  appState.saveDefaultHeaders(updated);
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppCardHeader(
            title: 'About',
            subtitle: 'Hoistbay information',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildInfoRow('Version', '1.1.1'),
          _buildInfoRow('App', 'Hoistbay — for Amazon S3 & CloudFront'),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'A free, open-source desktop app for Amazon S3 and CloudFront. Hoistbay is an independent project and is not affiliated with or endorsed by Amazon Web Services. Amazon S3, Amazon CloudFront and AWS are trademarks of Amazon.com, Inc. or its affiliates.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'This app was vibe coded with AI assistance and is proudly open source.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildInfoRow('Developer', 'Kartik Shah'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            children: [
              _buildLinkChip(
                icon: Icons.link,
                label: 'X / Twitter',
                url: 'https://x.com/mekartikshah',
              ),
              _buildLinkChip(
                icon: Icons.link,
                label: 'LinkedIn',
                url: 'https://linkedin.com/in/mekartikshah',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkChip({
    required IconData icon,
    required String label,
    required String url,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(label, style: AppTypography.captionMedium.copyWith(color: AppColors.primary)),
      backgroundColor: AppColors.selectionBlueLight,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.captionMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body,
            ),
          ),
        ],
      ),
    );
  }
}
