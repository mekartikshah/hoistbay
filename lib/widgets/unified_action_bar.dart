import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import '../models/task_history.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../components/app_button.dart';
import '../components/app_dialog.dart';
import '../components/app_input.dart';
import '../components/app_progress.dart';
import 'upload_button.dart';

class UnifiedActionBar extends StatefulWidget {
  const UnifiedActionBar({super.key});

  @override
  State<UnifiedActionBar> createState() => _UnifiedActionBarState();
}

class _UnifiedActionBarState extends State<UnifiedActionBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    context.read<AppState>().searchObjects(value);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<AppState>().clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Navigating (folder, breadcrumb, bucket) resets the query in AppState;
        // empty the box too so stale text doesn't leak into the next search.
        if (appState.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && context.read<AppState>().searchQuery.isEmpty) {
              _searchController.clear();
            }
          });
        }
        if (appState.selectedObjectKeys.isEmpty) {
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
                Expanded(
                  child: AppSearchField(
                    controller: _searchController,
                    hint: 'Search files and folders...',
                    onChanged: _onSearchChanged,
                    onClear: _clearSearch,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                AppIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  onPressed: () => appState.loadObjects(),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppIconButton(
                  icon: Icons.create_new_folder,
                  tooltip: 'Create Folder',
                  onPressed: () => UploadButton.showCreateFolderDialog(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                const UploadButton(),
              ],
            ),
          );
        }

        // Selection state
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.selectionBlueLight,
            border: Border(
              bottom: BorderSide(color: AppColors.borderLight),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${appState.selectedObjectKeys.length} selected',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              TextButton(
                onPressed: () => appState.selectAll(),
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed: () => appState.clearSelection(),
                child: const Text('Clear'),
              ),
              const Spacer(),
              AppIconButton(
                icon: Icons.download,
                tooltip: 'Download',
                color: AppColors.primary,
                onPressed: () => _downloadSelected(context, appState),
              ),
              if (appState.selectedObjectKeys.length == 1) ...[
                AppIconButton(
                  icon: Icons.edit,
                  tooltip: 'Rename',
                  color: AppColors.primary,
                  onPressed: () => _showRenameDialog(context, appState),
                ),
              ],
              AppIconButton(
                icon: Icons.content_copy,
                tooltip: 'Copy',
                color: AppColors.primary,
                onPressed: () => _showCopyDialog(context, appState),
              ),
              AppIconButton(
                icon: Icons.drive_file_move,
                tooltip: 'Move',
                color: AppColors.primary,
                onPressed: () => _showMoveDialog(context, appState),
              ),
              AppIconButton(
                icon: Icons.delete,
                tooltip: 'Delete',
                color: AppColors.error,
                onPressed: () => _showDeleteDialog(context, appState),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadSelected(BuildContext context, AppState appState) async {
    final keys = appState.selectedObjectKeys;
    if (keys.length > 1 || keys.first.endsWith('/')) {
      return _downloadToFolder(context, appState);
    }

    final object = appState.objects.firstWhere((o) => o.key == keys.first);
    final taskId = await appState.beginTask(
      type: 'Download',
      target: '${appState.selectedBucket!.name}/${object.key}',
      details: 'Downloading ${object.displaySize}',
    );
    try {
      final data = await appState.awsService.downloadObject(
        appState.selectedBucket!.name,
        object.key,
      );
      final uri = await FilePicker.saveFile(fileName: object.name, bytes: data);
      await appState.updateTaskStatus(
        taskId,
        uri != null ? TaskStatus.completed : TaskStatus.cancelled,
        details: uri != null ? 'Saved to $uri' : 'Save dialog dismissed',
      );
      if (context.mounted && uri != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${object.name} successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      await appState.updateTaskStatus(taskId, TaskStatus.failed, details: e.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download ${object.name}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Folders, or several items at once: pick a destination folder and
  /// download everything into it, keeping the folder structure.
  Future<void> _downloadToFolder(BuildContext context, AppState appState) async {
    final destDir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose where to download ${appState.selectedObjectKeys.length} item(s)',
    );
    if (destDir == null || !context.mounted) return;

    int downloaded = 0;
    bool succeeded = false;
    await _showOperationDialog(
      context,
      appState,
      () async {
        downloaded = await appState.downloadSelectedTo(destDir);
        // Read now: closing the error dialog clears operationError.
        succeeded = appState.operationError == null;
      },
      'Downloading',
    );

    if (context.mounted && succeeded && downloaded > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded $downloaded file(s) to $destDir'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        title: 'Delete Selected Objects',
        message: 'Are you sure you want to delete ${appState.selectedObjectKeys.length} selected object(s)?',
        confirmLabel: 'Delete',
        isDestructive: true,
        onConfirm: () {
          _showOperationDialog(
            context,
            appState,
            () => appState.deleteSelected(),
            'Deleting Objects',
          );
        },
      ),
    );
  }

  Future<void> _showOperationDialog(BuildContext context, AppState appState, Future<void> Function() action, String title) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _OperationProgressDialog(
        appState: appState,
        action: action,
        title: title,
      ),
    );
  }

  void _showRenameDialog(BuildContext context, AppState appState) {
    final oldKey = appState.selectedObjectKeys.first;
    final isFolder = oldKey.endsWith('/');
    final currentName = oldKey.split('/').where((p) => p.isNotEmpty).last;
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: isFolder ? 'Rename Folder' : 'Rename File',
        content: AppInput(
          controller: controller,
          label: 'New Name',
          hint: 'Enter new name',
          autofocus: true,
          onSubmitted: (_) => _doRename(context, appState, dialogContext, controller, currentName, oldKey),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AppButton(
            label: 'Rename',
            variant: AppButtonVariant.primary,
            onPressed: () => _doRename(context, appState, dialogContext, controller, currentName, oldKey),
          ),
        ],
      ),
    );
  }

  void _doRename(BuildContext context, AppState appState, BuildContext dialogContext,
      TextEditingController controller, String currentName, String oldKey) {
    final newName = controller.text.trim();
    if (newName.isNotEmpty && newName != currentName) {
      Navigator.pop(dialogContext);
      _showOperationDialog(
        context,
        appState,
        () => appState.renameItem(oldKey, newName),
        'Renaming Object',
      );
    }
  }

  void _showMoveDialog(BuildContext context, AppState appState) {
    final controller = TextEditingController(text: appState.currentPrefix);

    showDialog(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Move Selected Objects',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move ${appState.selectedObjectKeys.length} object(s) to prefix:',
              style: AppTypography.body,
            ),
            const SizedBox(height: AppSpacing.md),
            AppInput(
              controller: controller,
              label: 'Destination Prefix',
              hint: 'e.g. folder/subfolder/ (leave empty for root)',
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AppButton(
            label: 'Move',
            variant: AppButtonVariant.primary,
            onPressed: () {
              String destPrefix = controller.text.trim();
              if (destPrefix.isNotEmpty && !destPrefix.endsWith('/')) {
                destPrefix += '/';
              }
              Navigator.pop(dialogContext);
              _showOperationDialog(
                context,
                appState,
                () => appState.moveSelected(destPrefix),
                'Moving Objects',
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCopyDialog(BuildContext context, AppState appState) {
    final prefixController = TextEditingController(text: appState.currentPrefix);
    String selectedBucketName = appState.selectedBucket!.name;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AppDialog(
            title: 'Copy Selected Objects',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Copy ${appState.selectedObjectKeys.length} object(s) to:',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedBucketName,
                  decoration: const InputDecoration(
                    labelText: 'Destination Bucket',
                    border: OutlineInputBorder(),
                  ),
                  items: appState.buckets.map((bucket) {
                    return DropdownMenuItem<String>(
                      value: bucket.name,
                      child: Text(bucket.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedBucketName = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppInput(
                  controller: prefixController,
                  label: 'Destination Prefix',
                  hint: 'e.g. folder/subfolder/ (leave empty for root)',
                ),
              ],
            ),
            actions: [
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.pop(dialogContext),
              ),
              AppButton(
                label: 'Copy',
                variant: AppButtonVariant.primary,
                onPressed: () {
                  String destPrefix = prefixController.text.trim();
                  if (destPrefix.isNotEmpty && !destPrefix.endsWith('/')) {
                    destPrefix += '/';
                  }
                  Navigator.pop(dialogContext);
                  _showOperationDialog(
                    context,
                    appState,
                    () => appState.copySelected(selectedBucketName, destPrefix),
                    'Copying Objects',
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OperationProgressDialog extends StatefulWidget {
  final AppState appState;
  final Future<void> Function() action;
  final String title;

  const _OperationProgressDialog({
    required this.appState,
    required this.action,
    required this.title,
  });

  @override
  State<_OperationProgressDialog> createState() => _OperationProgressDialogState();
}

class _OperationProgressDialogState extends State<_OperationProgressDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAction());
  }

  Future<void> _runAction() async {
    try {
      await widget.action();
      if (mounted && widget.appState.operationError == null) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      // Error state is stored in appState; dialog will display it
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final bool hasError = appState.operationError != null;
        final bool isDone = !appState.operationInProgress && !hasError;

        if (isDone) {
          return const AppDialog(
            content: SizedBox(
              height: 60,
              child: Center(child: AppCircularProgress(size: 24, strokeWidth: 2)),
            ),
          );
        }

        return AppDialog(
          title: widget.title,
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasError) ...[
                  const Center(
                    child: Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Operation failed',
                    style: AppTypography.headline.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    appState.operationError!,
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ] else ...[
                  AppProgressIndicator(
                    value: appState.operationTotal > 0
                        ? appState.operationCurrent / appState.operationTotal
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '${appState.operationCurrent} / ${appState.operationTotal}',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    appState.operationMessage,
                    style: AppTypography.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!hasError && appState.operationInProgress)
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.text,
                onPressed: () => appState.cancelOperation(),
              ),
            if (hasError)
              AppButton(
                label: 'Close',
                variant: AppButtonVariant.text,
                onPressed: () {
                  appState.clearOperation();
                  Navigator.of(context).pop();
                },
              ),
          ],
        );
      },
    );
  }
}
