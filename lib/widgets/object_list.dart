import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/s3_object.dart';
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading objects...'),
              ],
            ),
          );
        }

        if (displayObjects.isEmpty && !appState.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  appState.error != null ? Icons.error : Icons.folder_open,
                  size: 64,
                  color: appState.error != null ? Colors.red : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  appState.error != null
                      ? 'Failed to load objects'
                      : isSearching
                          ? 'No results found'
                          : 'This folder is empty',
                  style: TextStyle(
                    fontSize: 18,
                    color: appState.error != null ? Colors.red.shade700 : Colors.grey,
                  ),
                ),
                if (appState.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    appState.error!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      appState.loadObjects();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        final selectedKey = appState.selectedObjectKeys.length == 1 ? appState.selectedObjectKeys.first : null;
        final allObjects = [...appState.objects, ...appState.filteredObjects];
        final selectedObject = selectedKey != null
            ? allObjects.firstWhere(
                (o) => o.key == selectedKey,
                orElse: () => S3Object(key: '', isFolder: true),
              )
            : null;
        final showDetailsPane = selectedObject != null && !selectedObject.isFolder && selectedObject.key.isNotEmpty;

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
              SizedBox(
                height: 300,
                child: ObjectDetailsPane(
                  object: selectedObject!,
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
    return InkWell(
      onTap: () {
        context.read<AppState>().toggleSelection(object.key);
      },
      onDoubleTap: object.isFolder ? () {
        context.read<AppState>().navigateToFolder(object.key);
      } : null,
      child: Container(
        color: isSelected ? Colors.blue.shade50 : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              object.isFolder ? Icons.folder : _getFileIcon(object.name),
              color: object.isFolder ? Colors.amber.shade700 : Colors.blue.shade700,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(object.name, style: const TextStyle(fontSize: 16)),
                  if (!object.isFolder) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Size: ${object.displaySize}  •  Modified: ${_formatDateTime(object.lastModified!)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            if (object.isFolder)
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: Colors.grey,
                onPressed: () {
                  context.read<AppState>().navigateToFolder(object.key);
                },
                tooltip: 'Open folder',
              ),
          ],
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