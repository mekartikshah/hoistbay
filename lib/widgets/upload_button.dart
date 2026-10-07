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
import '../utils/upload_paths.dart';
import '../utils/upload_runner.dart';

class UploadButton extends StatelessWidget {
  const UploadButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return AppButton(
          label: 'Upload',
          icon: Icons.upload,
          variant: AppButtonVariant.primary,
          onPressed: appState.selectedBucket == null || appState.isLoading
              ? null
              : () => _uploadFilesAndFolders(context),
        );
      },
    );
  }

  Future<void> _uploadFilesAndFolders(BuildContext context) async {
    try {
      final List<String> paths = await FilePicker.pickFileAndDirectoryPaths();
      await uploadPaths(context, paths);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  static Future<void> uploadPaths(BuildContext context, List<String> paths) async {
    if (paths.isEmpty) return;

    final appState = context.read<AppState>();
    final List<UploadItem> uploadItems = await collectUploadItems(paths);

    final int totalFiles = uploadItems.length;

    if (totalFiles == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No files to upload'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);
    final ValueNotifier<String> currentFileNotifier = ValueNotifier<String>('');

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AppDialog(
          title: 'Uploading Files & Folders',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: progressNotifier,
                builder: (context, count, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progress: $count / $totalFiles files', style: AppTypography.bodyMedium),
                      const SizedBox(height: AppSpacing.md),
                      AppProgressIndicator(
                        value: totalFiles > 0 ? count / totalFiles : 0,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ValueListenableBuilder<String>(
                valueListenable: currentFileNotifier,
                builder: (context, fileName, child) {
                  return Text(
                    'Uploading: $fileName',
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    final destination = '${appState.selectedBucket!.name}/${appState.currentPrefix}';
    final taskId = await appState.beginTask(
      type: 'Upload',
      target: '$totalFiles file(s) -> $destination',
      total: totalFiles,
    );

    int uploadedCount = 0;
    List<String> failedKeys = [];
    try {
      final result = await runUploads(
        uploadItems,
        (item, bytes) async {
          try {
            await appState.uploadObject(
              item.objectKey,
              bytes,
              contentType: _getContentType(item.localPath),
              refresh: false,
              recordTask: false,
            );
          } catch (e) {
            debugPrint('[upload] FAILED ${item.objectKey}: $e');
            rethrow;
          }
        },
        onStart: (item) => currentFileNotifier.value = item.objectKey,
        onProgress: (done, total) {
          progressNotifier.value = done;
          appState.updateTaskProgress(taskId, done);
        },
      );
      uploadedCount = result.uploaded;
      failedKeys = result.failed;
      await appState.updateTaskStatus(
        taskId,
        failedKeys.isEmpty ? TaskStatus.completed : TaskStatus.failed,
        details: failedKeys.isEmpty
            ? 'Uploaded $uploadedCount file(s)'
            : 'Uploaded $uploadedCount file(s), ${failedKeys.length} failed: ${failedKeys.take(5).join(', ')}'
                '${failedKeys.length > 5 ? ' (+${failedKeys.length - 5} more)' : ''}',
      );
      await appState.loadObjects();
    } catch (e) {
      await appState.updateTaskStatus(taskId, TaskStatus.failed, details: e.toString());
      rethrow;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    final int failedCount = failedKeys.length;
    if (context.mounted) {
      if (failedCount > 0) {
        final preview = failedKeys.take(3).join(', ');
        final suffix = failedCount > 3 ? ' (+${failedCount - 3} more)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded $uploadedCount file(s), $failedCount failed: $preview$suffix'),
            backgroundColor: failedCount == totalFiles ? AppColors.error : AppColors.warning,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded $uploadedCount file(s) successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  static void showCreateFolderDialog(BuildContext context) {
    final TextEditingController folderNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: 'Create Folder',
        content: AppInput(
          controller: folderNameController,
          label: 'Folder Name',
          hint: 'Enter folder name',
          autofocus: true,
          onSubmitted: (_) => _doCreateFolder(context, folderNameController),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppButton(
            label: 'Create',
            variant: AppButtonVariant.primary,
            onPressed: () => _doCreateFolder(context, folderNameController),
          ),
        ],
      ),
    );
  }

  static void _doCreateFolder(BuildContext context, TextEditingController controller) async {
    final folderName = controller.text.trim();
    if (folderName.isEmpty) return;

    Navigator.of(context).pop();

    try {
      final appState = context.read<AppState>();
      await appState.uploadObject(
        '$folderName/',
        [],
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created folder: $folderName'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create folder: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  static String? _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'html':
        return 'text/html';
      case 'css':
        return 'text/css';
      case 'js':
        return 'application/javascript';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      default:
        return null;
    }
  }
}
