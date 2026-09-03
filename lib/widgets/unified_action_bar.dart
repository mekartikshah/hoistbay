import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import 'upload_button.dart';

class UnifiedActionBar extends StatefulWidget {
  const UnifiedActionBar({super.key});

  @override
  State<UnifiedActionBar> createState() => _UnifiedActionBarState();
}

class _UnifiedActionBarState extends State<UnifiedActionBar> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Rebuild to show/hide clear button
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      context.read<AppState>().searchObjects(value);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<AppState>().clearSearch();
  }

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
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search files and folders...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Downloading ${object.name}...'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                      try {
                        final data = await appState.awsService.downloadObject(appState.selectedBucket!.name, object.key);
                        final uri = await FilePicker.saveFile(
                          fileName: object.name,
                          bytes: data,
                        );
                        if (context.mounted) {
                          if (uri != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Downloaded ${object.name} successfully.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to download ${object.name}: $e'),
                              backgroundColor: Colors.red,
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
                icon: const Icon(Icons.content_copy),
                tooltip: 'Copy',
                color: Colors.blue.shade700,
                onPressed: () => _showCopyDialog(context, appState),
              ),
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
              _showOperationDialog(
                context, 
                appState, 
                () => appState.deleteSelected(), 
                'Deleting Objects'
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showOperationDialog(BuildContext context, AppState appState, Future<void> Function() action, String title) {
    showDialog(
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
                _showOperationDialog(
                  context,
                  appState,
                  () => appState.renameItem(oldKey, newName),
                  'Renaming Object'
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
              _showOperationDialog(
                context,
                appState,
                () => appState.moveSelected(destPrefix),
                'Moving Objects'
              );
            },
            child: const Text('Move'),
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
          return AlertDialog(
            title: const Text('Copy Selected Objects'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Copy ${appState.selectedObjectKeys.length} object(s) to:'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedBucketName,
                  decoration: const InputDecoration(
                    labelText: 'Destination Bucket',
                    border: OutlineInputBorder(),
                  ),
                  items: appState.buckets.map((bucket) {
                    return DropdownMenuItem<String>(
                      value: bucket.name,
                      child: Text(bucket.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedBucketName = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: prefixController,
                  decoration: const InputDecoration(
                    labelText: 'Destination Prefix (e.g. folder/subfolder/)',
                    hintText: 'Leave empty for root',
                    border: OutlineInputBorder(),
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
                  String destPrefix = prefixController.text.trim();
                  if (destPrefix.isNotEmpty && !destPrefix.endsWith('/')) {
                    destPrefix += '/';
                  }
                  Navigator.pop(dialogContext);
                  _showOperationDialog(
                    context,
                    appState,
                    () => appState.copySelected(selectedBucketName, destPrefix),
                    'Copying Objects'
                  );
                },
                child: const Text('Copy'),
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
          // Should auto-close shortly; show minimal state to avoid flicker
          return const AlertDialog(
            content: SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        return AlertDialog(
          title: Text(widget.title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasError) ...[
                  const Center(
                    child: Icon(Icons.error_outline, color: Colors.red, size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Operation failed',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appState.operationError!,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ] else ...[
                  LinearProgressIndicator(
                    value: appState.operationTotal > 0
                        ? appState.operationCurrent / appState.operationTotal
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${appState.operationCurrent} / ${appState.operationTotal}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appState.operationMessage,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!hasError && appState.operationInProgress)
              TextButton(
                onPressed: () => appState.cancelOperation(),
                child: const Text('Cancel'),
              ),
            if (hasError)
              TextButton(
                onPressed: () {
                  appState.clearOperation();
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
          ],
        );
      },
    );
  }
}
