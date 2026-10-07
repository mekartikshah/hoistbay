import 'dart:io';

import 'upload_paths.dart';

/// Uploads [items] one by one through [upload]; returns how many succeeded and
/// the keys that failed. A failure of one item never stops the others.
///
/// [onStart] fires before each item, [onProgress] after each item finishes.
Future<({int uploaded, List<String> failed})> runUploads(
  List<UploadItem> items,
  Future<void> Function(UploadItem item, List<int> bytes) upload, {
  void Function(UploadItem item)? onStart,
  void Function(int done, int total)? onProgress,
}) async {
  var uploaded = 0;
  final failed = <String>[];
  var done = 0;
  for (final item in items) {
    onStart?.call(item);
    try {
      final bytes = await File(item.localPath).readAsBytes();
      await upload(item, bytes);
      uploaded++;
    } catch (_) {
      failed.add(item.objectKey);
    }
    done++;
    onProgress?.call(done, items.length);
  }
  return (uploaded: uploaded, failed: failed);
}
