import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/s3_object.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../components/app_button.dart';
import '../components/app_progress.dart';
import 'object_details_pane.dart';

class ObjectList extends StatelessWidget {
  const ObjectList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final isSearching = appState.searchQuery.isNotEmpty;
        final displayObjects = isSearching ? appState.filteredObjects : appState.objects;

        if (appState.isLoading && displayObjects.isEmpty) {
          return const AppLoadingOverlay(message: 'Loading objects...');
        }

        if (displayObjects.isEmpty && !appState.isLoading) {
          return AppEmptyState(
            icon: appState.error != null ? Icons.error_outline : Icons.folder_open,
            title: appState.error != null
                ? 'Failed to load objects'
                : isSearching
                    ? 'No results found'
                    : 'This folder is empty',
            subtitle: appState.error,
            action: appState.error != null
                ? AppButton(
                    label: 'Retry',
                    icon: Icons.refresh,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => appState.loadObjects(),
                  )
                : null,
          );
        }

        final selectedKey = appState.selectedObjectKeys.length == 1
            ? appState.selectedObjectKeys.first
            : null;
        final allObjects = [...appState.objects, ...appState.filteredObjects];
        final selectedObject = selectedKey != null
            ? allObjects.firstWhere(
                (o) => o.key == selectedKey,
                orElse: () => S3Object(key: '', isFolder: true),
              )
            : null;
        final showDetailsPane = selectedObject != null &&
            !selectedObject.isFolder &&
            selectedObject.key.isNotEmpty;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: displayObjects.length,
                itemBuilder: (context, index) {
                  final object = displayObjects[index];
                  final isSelected = appState.selectedObjectKeys.contains(object.key);
                  return _ObjectTile(
                    key: ValueKey(object.key),
                    object: object,
                    isSelected: isSelected,
                  );
                },
              ),
            ),
            if (showDetailsPane)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: 280,
                child: ObjectDetailsPane(
                  object: selectedObject,
                  bucketName: appState.selectedBucket!.name,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ObjectTile extends StatelessWidget {
  final S3Object object;
  final bool isSelected;

  const _ObjectTile({super.key, required this.object, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.selectionBlueLight : Colors.transparent,
      child: InkWell(
        onTap: () {
          context.read<AppState>().toggleSelection(object.key);
        },
        onDoubleTap: object.isFolder
            ? () {
                context.read<AppState>().navigateToFolder(object.key);
              }
            : null,
        hoverColor: AppColors.sidebarHover,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: object.isFolder
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Icon(
                    object.isFolder ? Icons.folder : _getFileIcon(object.name),
                    size: 18,
                    color: object.isFolder ? AppColors.warning : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      object.name,
                      style: AppTypography.body.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (!object.isFolder) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${object.displaySize}  •  ${_formatDateTime(object.lastModified!)}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ],
                ),
              ),
              if (object.isFolder)
                AppIconButton(
                  icon: Icons.chevron_right,
                  onPressed: () {
                    context.read<AppState>().navigateToFolder(object.key);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'mp4':
      case 'avi':
      case 'mkv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'txt':
      case 'md':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
