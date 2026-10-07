import 'package:flutter_test/flutter_test.dart';
import 'package:s3_scout/utils/download_paths.dart';

void main() {
  group('localPathForKey', () {
    test('keeps the selected folder and its structure under the destination', () {
      expect(
        localPathForKey('/Users/me/Downloads', 'data/', 'data/photos/2024/a.jpg'),
        '/Users/me/Downloads/photos/2024/a.jpg',
      );
    });

    test('works at the bucket root', () {
      expect(
        localPathForKey('/dest', '', 'photos/a.jpg'),
        '/dest/photos/a.jpg',
      );
    });

    test('a trailing slash on the destination is not doubled', () {
      expect(localPathForKey('/dest/', '', 'a.txt'), '/dest/a.txt');
    });

    test('folder markers produce nothing to write', () {
      expect(localPathForKey('/dest', 'data/', 'data/photos/'), isNull);
    });

    test('keys outside the browsed prefix are ignored', () {
      expect(localPathForKey('/dest', 'data/', 'other/a.txt'), isNull);
    });

    test('a key cannot escape the destination folder', () {
      expect(localPathForKey('/dest', '', '../../etc/passwd'), isNull);
      expect(localPathForKey('/dest', 'data/', 'data/x/../../../a.txt'), isNull);
    });

    test('empty and "." segments are dropped', () {
      expect(
        localPathForKey('/dest', '', 'photos//./a.jpg'),
        '/dest/photos/a.jpg',
      );
    });
  });
}
