/// Maps an S3 object [key] to the local path it should be saved at when
/// downloading into [destDir].
///
/// The key is taken relative to [basePrefix] (the folder currently being
/// browsed), so downloading `photos/` while viewing `data/` writes
/// `data/photos/2024/a.jpg` to `<destDir>/photos/2024/a.jpg`.
///
/// Returns null when the key has nothing to write (a folder marker or a key
/// outside [basePrefix]) or would escape [destDir] via a `..` segment.
String? localPathForKey(String destDir, String basePrefix, String key) {
  if (key.endsWith('/') || !key.startsWith(basePrefix)) return null;

  final segments = key
      .substring(basePrefix.length)
      .split('/')
      .where((s) => s.isNotEmpty && s != '.')
      .toList();
  if (segments.isEmpty || segments.contains('..')) return null;

  final base = destDir.replaceFirst(RegExp(r'[/\\]+$'), '');
  return '$base/${segments.join('/')}';
}
