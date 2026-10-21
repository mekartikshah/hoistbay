// Runs ProfileService against the real Windows plugins: DPAPI-encrypted
// flutter_secure_storage and the shared_preferences JSON file. The unit tests
// in test/ use in-memory mocks, so this is the only check of the real storage.
//
// Windows only, and meant for CI: it wipes Hoistbay's saved profiles. On a Mac
// it would overwrite your real Keychain item, so it skips itself there.
//
//   flutter test integration_test -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoistbay/models/aws_credentials.dart';
import 'package:hoistbay/services/credential_store.dart';
import 'package:hoistbay/services/profile_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secret = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';

Map<String, dynamic> _legacyProfile(String id) => {
      'id': id,
      'name': 'Profile $id',
      'credentials': {
        'accessKeyId': 'AKIATEST$id',
        'secretAccessKey': _secret,
        'region': 'eu-west-1',
        'sessionToken': null,
      },
      'createdAt': '2026-01-01T00:00:00.000',
      'lastUsed': '2026-01-01T00:00:00.000',
    };

Future<File> _supportFile(String name) async =>
    File('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}$name');

/// What shared_preferences actually wrote to disk.
Future<String> _prefsOnDisk() async {
  final file = await _supportFile('shared_preferences.json');
  return file.existsSync() ? file.readAsStringSync() : '';
}

Future<File> _secureStoreFile() => _supportFile('flutter_secure_storage.dat');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final skip = Platform.isWindows ? false : 'Windows only: would overwrite the real macOS Keychain item';

  setUpAll(() async {
    if (!Platform.isWindows) return;
    await (await SharedPreferences.getInstance()).clear();
    final store = await _secureStoreFile();
    if (store.existsSync()) store.deleteSync();
  });

  test('moves plaintext keys out of the preferences file', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aws_profiles', jsonEncode([_legacyProfile('1'), _legacyProfile('2')]));
    await prefs.setString('aws_credentials', jsonEncode({'secretAccessKey': _secret}));
    expect(await _prefsOnDisk(), contains(_secret), reason: 'the test should start from plaintext');

    final profiles = await ProfileService.loadProfiles();

    expect(profiles.map((p) => p.credentials.secretAccessKey), [_secret, _secret]);
    expect(profiles.first.credentials.accessKeyId, 'AKIATEST1');
    expect(await _prefsOnDisk(), isNot(contains(_secret)));
    expect(await _prefsOnDisk(), isNot(contains('AKIATEST')));

    final store = await _secureStoreFile();
    expect(store.existsSync(), isTrue);
    expect(latin1.decode(store.readAsBytesSync()), isNot(contains(_secret)),
        reason: 'the DPAPI file must be encrypted');
  }, skip: skip);

  test('saving and editing never writes keys to the preferences file', () async {
    final profile = ProfileService.createProfile(
      name: 'Work',
      credentials: AwsCredentials(
        accessKeyId: 'AKIATESTWORK',
        secretAccessKey: _secret,
        region: 'ap-south-1',
        sessionToken: 'test-session-token',
      ),
    );
    await ProfileService.saveProfile(profile);
    await ProfileService.saveProfile(profile.copyWith(name: 'Work (edited)'));
    await ProfileService.updateProfileLastUsed(profile.id);

    expect(await _prefsOnDisk(), contains('Work (edited)'));
    expect(await _prefsOnDisk(), isNot(anyOf(contains(_secret), contains('AKIATESTWORK'), contains('test-session-token'))));

    final loaded = (await ProfileService.loadProfiles()).firstWhere((p) => p.id == profile.id);
    expect(loaded.credentials.secretAccessKey, _secret);
    expect(loaded.credentials.sessionToken, 'test-session-token');
  }, skip: skip);

  test('deleting a profile removes its keys', () async {
    await ProfileService.deleteProfile('1');

    final profiles = await ProfileService.loadProfiles();
    expect(profiles.map((p) => p.id), isNot(contains('1')));
    expect((await CredentialStore.loadAll()).keys, isNot(contains('1')));
  }, skip: skip);

  test('an unreadable store gives a clear error, then profiles with no keys', () async {
    (await _secureStoreFile()).writeAsStringSync('not-encrypted');

    await expectLater(
      ProfileService.loadProfiles(),
      throwsA(isA<KeychainException>().having((e) => e.title, 'title', 'Could not read your saved keys')),
    );

    // The plugin deletes a file it can't decrypt, so the profiles come back
    // without keys; AppState.login turns that into "keys are missing".
    final profiles = await ProfileService.loadProfiles();
    expect(profiles, isNotEmpty);
    expect(profiles.every((p) => p.credentials.secretAccessKey.isEmpty), isTrue);
  }, skip: skip);
}
