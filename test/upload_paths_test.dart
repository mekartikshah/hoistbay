import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s3_scout/utils/upload_paths.dart';
import 'package:s3_scout/utils/upload_runner.dart';

void main() {
  late Directory root;
  late String photoDir;

  setUp(() {
    root = Directory.systemTemp.createTempSync('upload_paths_test');
    photoDir = '${root.path}/photo';
    Directory('$photoDir/sub/deep').createSync(recursive: true);
    File('$photoDir/a.txt').writeAsStringSync('a');
    File('$photoDir/b.jpg').writeAsStringSync('b');
    File('$photoDir/sub/c.txt').writeAsStringSync('c');
    File('$photoDir/sub/deep/d.txt').writeAsStringSync('d');
  });

  tearDown(() => root.deleteSync(recursive: true));

  List<String> keysOf(List<UploadItem> items) =>
      items.map((e) => e.objectKey).toList()..sort();

  const allPhotoKeys = [
    'photo/a.txt',
    'photo/b.jpg',
    'photo/sub/c.txt',
    'photo/sub/deep/d.txt',
  ];

  group('collectUploadItems', () {
    test('folder upload includes files sitting in the folder root', () async {
      final items = await collectUploadItems([photoDir]);
      expect(keysOf(items), allPhotoKeys);
    });

    test('trailing slash on the selected folder yields the same keys', () async {
      final items = await collectUploadItems(['$photoDir/']);
      expect(keysOf(items), allPhotoKeys);
    });

    test('a selected file uploads under its own name', () async {
      final items = await collectUploadItems(['$photoDir/a.txt']);
      expect(keysOf(items), ['a.txt']);
      expect(items.single.localPath, '$photoDir/a.txt');
    });

    test('files and folders can be mixed in one selection', () async {
      final items =
          await collectUploadItems(['$photoDir/sub', '$photoDir/b.jpg']);
      expect(keysOf(items), ['b.jpg', 'sub/c.txt', 'sub/deep/d.txt']);
    });

    test('missing paths are skipped', () async {
      final items = await collectUploadItems(['$photoDir/nope']);
      expect(items, isEmpty);
    });
  });

  group('runUploads', () {
    test('a failing upload is reported, not counted as success', () async {
      final items = [
        UploadItem(localPath: '$photoDir/a.txt', objectKey: 'photo/a.txt'),
        UploadItem(localPath: '$photoDir/b.jpg', objectKey: 'photo/b.jpg'),
      ];
      final progress = <int>[];

      final result = await runUploads(
        items,
        (item, bytes) async {
          if (item.objectKey.endsWith('a.txt')) {
            throw const SocketException('simulated PUT failure');
          }
        },
        onProgress: (done, total) => progress.add(done),
      );

      expect(result.uploaded, 1);
      expect(result.failed, ['photo/a.txt']);
      expect(progress, [1, 2]);
    });

    test('an unreadable local file is reported as failed', () async {
      final result = await runUploads(
        [UploadItem(localPath: '$photoDir/gone.txt', objectKey: 'gone.txt')],
        (item, bytes) async {},
      );

      expect(result.uploaded, 0);
      expect(result.failed, ['gone.txt']);
    });
  });
}
