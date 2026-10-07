/// Result of parsing the invalidation path box: the paths to send, or an error
/// message to show instead.
typedef ParsedInvalidationPaths = ({List<String> paths, String? error});

/// CloudFront allows at most 3000 paths per invalidation (15 with wildcards).
const int maxInvalidationPaths = 3000;
const int maxWildcardInvalidationPaths = 15;

/// Parses user input (one path per line, or comma separated) into CloudFront
/// invalidation paths: trims each one, adds the leading `/` CloudFront
/// requires, and drops blanks and duplicates. A `*` is only valid as the last
/// character of a path.
ParsedInvalidationPaths parseInvalidationPaths(String input) {
  final paths = <String>[];
  for (final raw in input.split(RegExp(r'[\n,]'))) {
    var path = raw.trim();
    if (path.isEmpty) continue;
    if (!path.startsWith('/')) path = '/$path';
    if (path.indexOf('*') case final i when i != -1 && i != path.length - 1) {
      return (paths: const <String>[], error: 'A * is only allowed at the end of a path: $path');
    }
    if (!paths.contains(path)) paths.add(path);
  }

  if (paths.isEmpty) {
    return (paths: const <String>[], error: 'Enter at least one path, e.g. /*');
  }
  final wildcards = paths.where((p) => p.endsWith('*')).length;
  if (wildcards > maxWildcardInvalidationPaths) {
    return (paths: const <String>[], error: 'At most $maxWildcardInvalidationPaths wildcard paths per invalidation');
  }
  if (paths.length > maxInvalidationPaths) {
    return (paths: const <String>[], error: 'At most $maxInvalidationPaths paths per invalidation');
  }
  return (paths: paths, error: null);
}
