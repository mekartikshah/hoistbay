import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import 'upload_button.dart';

class UnifiedActionBar extends StatelessWidget {
  const UnifiedActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.selectedObjectKeys.isEmpty) {
          // Default State: No selection
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: () {
                    appState.loadObjects(); // Refresh current prefix
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                const UploadButton(),
              ],
            ),
          );
        }

        // Selection State
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.blue.shade200),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${appState.selectedObjectKeys.length} selected',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () => appState.selectAll(),
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed: () => appState.clearSelection(),
                child: const Text('Clear'),
              ),
              const Spacer(),
              if (appState.selectedObjectKeys.length == 1) ...[
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Download',
                  color: Colors.blue.shade700,
                  onPressed: () async {
                    final object = appState.objects.firstWhere((o) => o.key == appState.selectedObjectKeys.first);
                    if (!object.isFolder) {
                      final savePath = await FilePicker.platform.saveFile(
                        dialogTitle: 'Save ${object.name}',
                        fileName: object.name,
                      );
                      if (savePath == null) return; // User cancelled
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Downloading ${object.name}...'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                      await appState.downloadObject(object, savePath);
                      if (appState.error == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Downloaded ${object.name} successfully.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cannot download folders directly.')),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Rename',
                  color: Colors.blue.shade700,
                  onPressed: () => _showRenameDialog(context, appState),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.drive_file_move),
                tooltip: 'Move',
                color: Colors.blue.shade700,
                onPressed: () => _showMoveDialog(context, appState),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete',
                onPressed: () => _showDeleteDialog(context, appState),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Selected Objects'),
        content: Text('Are you sure you want to delete ${appState.selectedObjectKeys.length} selected object(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dialogContext);
              _executeWithLoading(
                context, 
                appState, 
                () => appState.deleteSelected(), 
                'Deleting objects...'
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeWithLoading(BuildContext context, AppState appState, Future<void> Function() action, String loadingMessage) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(loadingMessage)),
          ],
        ),
      ),
    );

    await action();

    if (context.mounted) {
      Navigator.pop(context); // close loading dialog
      if (appState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.error!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operation completed successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showRenameDialog(BuildContext context, AppState appState) {
    final oldKey = appState.selectedObjectKeys.first;
    final isFolder = oldKey.endsWith('/');
    final currentName = oldKey.split('/').where((p) => p.isNotEmpty).last;
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isFolder ? 'Rename Folder' : 'Rename File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Name',
            hintText: 'Enter new name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                Navigator.pop(dialogContext);
                _executeWithLoading(
                  context,
                  appState,
                  () => appState.renameItem(oldKey, newName),
                  'Renaming object...'
                );
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showMoveDialog(BuildContext context, AppState appState) {
    final controller = TextEditingController(text: appState.currentPrefix);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move Selected Objects'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Move ${appState.selectedObjectKeys.length} object(s) to prefix:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Destination Prefix (e.g. folder/subfolder/)',
                hintText: 'Leave empty for root',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              String destPrefix = controller.text.trim();
              if (destPrefix.isNotEmpty && !destPrefix.endsWith('/')) {
                destPrefix += '/';
              }
              Navigator.pop(dialogContext);
              _executeWithLoading(
                context,
                appState,
                () => appState.moveSelected(destPrefix),
                'Moving objects...'
              );
            },
            child: const Text('Move'),
          ),
        ],
      ),
    );
  }
}
