import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aws_cloudfront_api/cloudfront-2020-05-31.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../components/app_button.dart';
import '../components/app_progress.dart';
import '../components/app_dialog.dart';
import '../components/app_input.dart';
import '../utils/invalidation_paths.dart';

class CloudFrontManagerScreen extends StatelessWidget {
  const CloudFrontManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CloudFront Manager')),
      body: const CloudFrontManagerView(),
    );
  }
}

class CloudFrontManagerView extends StatefulWidget {
  const CloudFrontManagerView({super.key});

  @override
  State<CloudFrontManagerView> createState() => _CloudFrontManagerViewState();
}

class _CloudFrontManagerViewState extends State<CloudFrontManagerView> {
  List<DistributionSummary> _distributions = [];
  DistributionSummary? _selectedDistribution;
  bool _isLoading = true;
  String? _error;

  List<InvalidationSummary> _invalidations = [];
  bool _invalidationsLoading = false;
  String? _invalidationsError;

  StreamSubscription<AppNotice>? _noticeSub;

  @override
  void initState() {
    super.initState();
    _loadDistributions();
    // A cache clear finishing changes the invalidation list; refresh it.
    _noticeSub = context.read<AppState>().notices.listen((_) {
      if (mounted && _selectedDistribution != null) _loadInvalidations();
    });
  }

  @override
  void dispose() {
    _noticeSub?.cancel();
    super.dispose();
  }

  void _selectDistribution(DistributionSummary dist) {
    setState(() {
      _selectedDistribution = dist;
      _invalidations = [];
    });
    _loadInvalidations();
  }

  Future<void> _loadInvalidations() async {
    final distId = _selectedDistribution?.id;
    if (distId == null) return;
    setState(() {
      _invalidationsLoading = true;
      _invalidationsError = null;
    });

    try {
      final items = await context.read<AppState>().cloudFrontService.listInvalidations(distId);
      // Ignore results for a distribution the user has already moved away from.
      if (!mounted || _selectedDistribution?.id != distId) return;
      setState(() {
        _invalidations = items;
        _invalidationsLoading = false;
      });
    } catch (e) {
      if (!mounted || _selectedDistribution?.id != distId) return;
      setState(() {
        _invalidationsError = e.toString();
        _invalidationsLoading = false;
      });
    }
  }

  void _showClearCacheDialog() {
    final dist = _selectedDistribution!;
    final controller = TextEditingController(text: '/*');
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            final parsed = parseInvalidationPaths(controller.text);
            if (parsed.error != null) {
              setDialogState(() => error = parsed.error);
              return;
            }
            setDialogState(() {
              error = null;
              submitting = true;
            });
            try {
              await appState.clearCloudFrontCache(
                distributionId: dist.id,
                domainName: dist.domainName,
                paths: parsed.paths,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              messenger.showSnackBar(SnackBar(
                content: Text(
                  'Cache clear started for ${parsed.paths.length} path(s). '
                  "You'll be notified when it's done. Track it under Activity.",
                ),
                backgroundColor: AppColors.success,
                action: SnackBarAction(
                  label: 'View',
                  textColor: AppColors.textInverse,
                  onPressed: () => appState.selectSection(AppSection.activity),
                ),
              ));
              if (mounted && _selectedDistribution?.id == dist.id) _loadInvalidations();
            } catch (e) {
              setDialogState(() {
                error = e.toString();
                submitting = false;
              });
            }
          }

          return AppDialog(
            title: 'Clear CloudFront Cache',
            maxWidth: 520,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creates an invalidation on ${dist.id} (${dist.domainName}). '
                  'Viewers get fresh copies from the origin on their next request.',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppInput(
                  controller: controller,
                  label: 'Paths (one per line)',
                  hint: '/*\n/index.html\n/images/*',
                  maxLines: 6,
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Use /* to clear everything. A * is allowed only at the end of a path. '
                  'AWS bills each path beyond the first 1,000 per month; /* counts as one.',
                  style: AppTypography.caption,
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(error!, style: AppTypography.caption.copyWith(color: AppColors.error)),
                ],
              ],
            ),
            actions: [
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.text,
                onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              ),
              AppButton(
                label: submitting ? 'Clearing...' : 'Clear Cache',
                variant: AppButtonVariant.primary,
                onPressed: submitting ? null : submit,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadDistributions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cloudFrontService = context.read<AppState>().cloudFrontService;
      final dists = await cloudFrontService.listDistributions();
      if (!mounted) return;
      setState(() {
        _distributions = dists;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _distributions.isEmpty) {
      return const AppLoadingOverlay(message: 'Loading CloudFront distributions...');
    }

    if (_error != null && _distributions.isEmpty) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Failed to load distributions',
        subtitle: _error,
        action: AppButton(
          label: 'Retry',
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: _loadDistributions,
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(color: AppColors.borderLight),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Distributions',
                  style: AppTypography.headline,
                ),
                const Spacer(),
                AppIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  onPressed: _loadDistributions,
                ),
              ],
            ),
          ),
          // List section
          Expanded(
            flex: 3,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _distributions.length,
              itemBuilder: (context, index) {
                final dist = _distributions[index];
                final isSelected = _selectedDistribution?.id == dist.id;
                return _DistributionCard(
                  distribution: dist,
                  isSelected: isSelected,
                  onTap: () => _selectDistribution(dist),
                );
              },
            ),
          ),
          // Details section
          if (_selectedDistribution != null)
            Expanded(
              flex: 2,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  border: Border(
                    top: BorderSide(color: AppColors.borderLight),
                  ),
                ),
                child: _buildDetailsPane(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsPane() {
    final dist = _selectedDistribution!;
    final origin = (dist.origins.items.isNotEmpty) ? dist.origins.items.first.domainName : '-';
    final aliasItems = dist.aliases.items;
    final aliases = (aliasItems != null && aliasItems.isNotEmpty)
        ? aliasItems.join(', ')
        : '-';
    final allowedConnections = dist.defaultCacheBehavior.viewerProtocolPolicy.toValue();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Distribution Properties', style: AppTypography.headline),
              const Spacer(),
              AppButton(
                label: 'Clear Cache',
                icon: Icons.cleaning_services_outlined,
                variant: AppButtonVariant.primary,
                onPressed: _showClearCacheDialog,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildPropertyRow('Distribution ID', dist.id),
                    _buildPropertyRow('Status', dist.enabled ? 'Enabled' : 'Disabled'),
                    _buildDomainNameRow(dist.domainName),
                    _buildPropertyRow('State', dist.status),
                    _buildPropertyRow('Last Modified', dist.lastModifiedTime.toString()),
                    _buildPropertyRow('Origin', origin),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(
                child: Column(
                  children: [
                    _buildPropertyRow('Allowed Connections', allowedConnections),
                    _buildPropertyRow('CNAMEs', aliases),
                    _buildPropertyRow('Default Root Object', '-'),
                    _buildPropertyRow('Logging', 'Disabled'),
                    _buildPropertyRow('Comment', dist.comment),
                    _buildPropertyRow('Min TTL', '${dist.defaultCacheBehavior.minTTL ?? 0} second(s)'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildInvalidationsSection(),
        ],
      ),
    );
  }

  Widget _buildInvalidationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recent Invalidations', style: AppTypography.headline),
            const Spacer(),
            AppIconButton(
              icon: Icons.refresh,
              tooltip: 'Refresh invalidations',
              onPressed: _invalidationsLoading ? null : _loadInvalidations,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_invalidationsLoading && _invalidations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: AppCircularProgress(size: 20, strokeWidth: 2),
          )
        else if (_invalidationsError != null)
          Text(_invalidationsError!, style: AppTypography.caption.copyWith(color: AppColors.error))
        else if (_invalidations.isEmpty)
          Text('No invalidations yet.', style: AppTypography.caption)
        else
          for (final inv in _invalidations)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(width: 160, child: Text(inv.id, style: AppTypography.body)),
                  AppStatusBadge(
                    label: inv.status,
                    color: inv.status == 'Completed' ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(inv.createTime.toLocal().toString().split('.').first, style: AppTypography.caption),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
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

  Widget _buildDomainNameRow(String domainName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              'Domain Name',
              style: AppTypography.captionMedium,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    domainName,
                    style: AppTypography.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppIconButton(
                  icon: Icons.copy,
                  tooltip: 'Copy to clipboard',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: domainName));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied $domainName to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  final DistributionSummary distribution;
  final bool isSelected;
  final VoidCallback onTap;

  const _DistributionCard({
    required this.distribution,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final origin = (distribution.origins.items.isNotEmpty)
        ? distribution.origins.items.first.domainName
        : '-';

    Color statusColor;
    if (distribution.status == 'Deployed') {
      statusColor = AppColors.success;
    } else if (distribution.status == 'InProgress') {
      statusColor = AppColors.warning;
    } else {
      statusColor = AppColors.error;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.selectionBlueLight : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.borderLight,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.language,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      distribution.id,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      distribution.domainName,
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Origin: $origin',
                      style: AppTypography.small,
                    ),
                  ],
                ),
              ),
              AppStatusBadge(
                label: distribution.status,
                color: statusColor,
              ),
              const SizedBox(width: AppSpacing.md),
              if (distribution.enabled)
                const AppStatusBadge(
                  label: 'Enabled',
                  color: AppColors.success,
                )
              else
                const AppStatusBadge(
                  label: 'Disabled',
                  color: AppColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
