import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';

class UploadButton extends StatelessWidget {
  const UploadButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return ElevatedButton.icon(
          onPressed: appState.selectedBucket == null || appState.isLoading
              ? null
              : () => _showUploadOptions(context),
          icon: const Icon(Icons.upload),
          label: const Text('Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Upload Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Upload Files'),
              subtitle: const Text('Select one or more files to upload'),
              onTap: () {
                Navigator.pop(sheetContext);
                _uploadFiles(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Upload Folder'),
              subtitle: const Text('Select a folder to upload its contents'),
              onTap: () {
                Navigator.pop(sheetContext);
                _uploadFolder(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('Create Folder'),
              subtitle: const Text('Create a new folder'),
              onTap: () {
                Navigator.pop(sheetContext);
                _createFolder(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFiles(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final appState = context.read<AppState>();
        
        final int totalFiles = result.files.length;
        int uploadedCount = 0;
        int failedCount = 0;
        final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);
        final ValueNotifier<String> currentFileNotifier = ValueNotifier<String>('');
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('Uploading Files'),
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
                          Text('Progress: $count / $totalFiles files'),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: totalFiles > 0 ? count / totalFiles : 0,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                    valueListenable: currentFileNotifier,
                    builder: (context, fileName, child) {
                      return Text(
                        'Uploading: $fileName',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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

        try {
          for (final file in result.files) {
            currentFileNotifier.value = file.name;
            
            try {
              // Get bytes: prefer in-memory bytes, fall back to reading from path (macOS desktop)
              List<int>? bytes = file.bytes;
              if (bytes == null && file.path != null) {
                bytes = await File(file.path!).readAsBytes();
              }
              
              if (bytes != null) {
                await appState.uploadObject(
                  file.name,
                  bytes,
                  contentType: _getContentType(file.name),
                  refresh: false,
                );
                uploadedCount++;
              } else {
                failedCount++;
                print('Skipping ${file.name}: no bytes or path available');
              }
            } catch (e) {
              failedCount++;
              print('Failed to upload ${file.name}: $e');
            }
            progressNotifier.value = uploadedCount + failedCount;
          }
          await appState.loadObjects();
        } finally {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }

        if (context.mounted) {
          if (failedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Uploaded $uploadedCount file(s), $failedCount failed'),
                backgroundColor: failedCount == totalFiles ? Colors.red : Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Uploaded $uploadedCount file(s) successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadFolder(BuildContext context) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        final appState = context.read<AppState>();
        final dir = Directory(selectedDirectory);
        final folderName = dir.uri.pathSegments.where((e) => e.isNotEmpty).last;

        List<File> filesToUpload = [];
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            filesToUpload.add(entity);
          }
        }
        
        final int totalFiles = filesToUpload.length;

        if (totalFiles == 0) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Folder is empty'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        
        int uploadedCount = 0;
        final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);
        final ValueNotifier<String> currentFileNotifier = ValueNotifier<String>('');

        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('Uploading Folder'),
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
                          Text('Progress: $count / $totalFiles files'),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: totalFiles > 0 ? count / totalFiles : 0,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                    valueListenable: currentFileNotifier,
                    builder: (context, fileName, child) {
                      return Text(
                        'Uploading: $fileName',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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

        try {
          for (final file in filesToUpload) {
            final relativePath = file.path.substring(selectedDirectory.length);
            final cleanRelativePath = relativePath.replaceAll('\\', '/').replaceFirst(RegExp(r'^/'), '');
            final objectKey = '$folderName/$cleanRelativePath';
            
            currentFileNotifier.value = cleanRelativePath;
            
            final bytes = await file.readAsBytes();
            
            await appState.uploadObject(
              objectKey,
              bytes,
              contentType: _getContentType(file.path),
              refresh: false,
            );
            uploadedCount++;
            progressNotifier.value = uploadedCount;
          }
          await appState.loadObjects();
        } finally {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploaded $uploadedCount file(s) from $folderName successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Folder upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _createFolder(BuildContext context) {
    final TextEditingController folderNameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: folderNameController,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'Enter folder name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final folderName = folderNameController.text.trim();
              if (folderName.isNotEmpty) {
                Navigator.of(context).pop();
                
                try {
                  // Create an empty object with folder name ending with /
                  final appState = context.read<AppState>();
                  await appState.uploadObject(
                    '$folderName/',
                    [],
                  );
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Created folder: $folderName'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create folder: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  String? _getContentType(String fileName) {
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