import 'package:flutter_test/flutter_test.dart';
import 'package:hoistbay/utils/invalidation_paths.dart';

void main() {
  group('parseInvalidationPaths', () {
    test('accepts the clear-everything wildcard', () {
      final r = parseInvalidationPaths('/*');
      expect(r.error, isNull);
      expect(r.paths, ['/*']);
    });

    test('splits on newlines and commas, trims, adds the leading slash', () {
      final r = parseInvalidationPaths(' index.html \n/css/*, js/app.js\n\n');
      expect(r.error, isNull);
      expect(r.paths, ['/index.html', '/css/*', '/js/app.js']);
    });

    test('drops duplicates', () {
      expect(parseInvalidationPaths('/a\na\n/a').paths, ['/a']);
    });

    test('rejects empty input', () {
      expect(parseInvalidationPaths('  \n ').error, isNotNull);
    });

    test('rejects a wildcard that is not at the end', () {
      final r = parseInvalidationPaths('/images/*/thumb.png');
      expect(r.error, contains('/images/*/thumb.png'));
      expect(r.paths, isEmpty);
    });

    test('enforces the wildcard limit', () {
      final input = List.generate(16, (i) => '/dir$i/*').join('\n');
      expect(parseInvalidationPaths(input).error, isNotNull);
      final ok = List.generate(15, (i) => '/dir$i/*').join('\n');
      expect(parseInvalidationPaths(ok).error, isNull);
    });
  });
}
