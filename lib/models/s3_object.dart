class S3Object {
  final String key;
  final int? size;
  final DateTime? lastModified;
  final String? etag;
  final bool isFolder;

  S3Object({
    required this.key,
    this.size,
    this.lastModified,
    this.etag,
    required this.isFolder,
  });

  String get name {
    if (isFolder && key.endsWith('/')) {
      return key.substring(0, key.length - 1).split('/').last;
    }
    return key.split('/').last;
  }

  String get displaySize {
    if (size == null || isFolder) return '';
    if (size! < 1024) return '${size!} B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    if (size! < 1024 * 1024 * 1024) return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class S3Bucket {
  final String name;
  final DateTime? creationDate;

  S3Bucket({
    required this.name,
    this.creationDate,
  });
}