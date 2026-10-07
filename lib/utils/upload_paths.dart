import 'dart:io';

/// A local file paired with the S3 object key it should be uploaded as.
class UploadItem {
  final String localPath;
  final String objectKey;

  const UploadItem({required this.localPath, required this.objectKey});
}

Stream<FileSystemEntity> _listDir(String path) =>
    Directory(path).list(recursive: true, followLinks: false);

/// Expands picker / drag-and-drop paths into concrete upload items.
///
/// A selected file becomes one item keyed by its file name. A selected
/// directory is walked recursively and every file inside becomes an item keyed
/// `<folderName>/<path relative to the selected directory>` — including the
/// files that sit directly in the selected directory's root.
Future<List<UploadItem>> collectUploadItems(
  List<String> paths, {
  FileSystemEntityType Function(String path) typeOf = FileSystemEntity.typeSync,
  Stream<FileSystemEntity> Function(String path) listDir = _listDir,
}) async {
  final items = <UploadItem>[];

  for (final path in paths) {
    switch (typeOf(path)) {
      case FileSystemEntityType.file:
        items.add(UploadItem(
          localPath: path,
          objectKey: path.split(RegExp(r'[/\\]')).last,
        ));
      case FileSystemEntityType.directory:
        final base = path.replaceFirst(RegExp(r'[/\\]+$'), '');
        final folderName = base.split(RegExp(r'[/\\]')).last;
        await for (final entity in listDir(base)) {
          if (entity is! File) continue;
          final relative = entity.path
              .substring(base.length)
              .replaceAll('\\', '/')
              .replaceFirst(RegExp(r'^/+'), '');
          if (relative.isEmpty) continue;
          items.add(UploadItem(
            localPath: entity.path,
            objectKey: '$folderName/$relative',
          ));
        }
      default:
        continue; // links, missing paths, sockets
    }
  }

  return items;
}
