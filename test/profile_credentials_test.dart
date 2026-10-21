import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoistbay/models/aws_credentials.dart';
import 'package:hoistbay/services/credential_store.dart';
import 'package:hoistbay/services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secret = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';

Map<String, dynamic> _legacyProfile(String id) => {
      'id': id,
      'name': 'Profile $id',
      'credentials': {
        'accessKeyId': 'AKIA$id',
        'secretAccessKey': _secret,
        'region': 'eu-west-1',
        'sessionToken': null,
      },
      'createdAt': '2026-01-01T00:00:00.000',
      'lastUsed': '2026-01-01T00:00:00.000',
    };

Future<String> _prefsJson() async =>
    (await SharedPreferences.getInstance()).getString('aws_profiles') ?? '';

Future<String?> _keychainJson() => const FlutterSecureStorage().read(key: 'aws_profile_secrets');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('moves plaintext keys from preferences into the Keychain', () async {
    SharedPreferences.setMockInitialValues({
      'aws_profiles': jsonEncode([_legacyProfile('1'), _legacyProfile('2')]),
      'aws_credentials': jsonEncode({'secretAccessKey': _secret}),
    });

    final profiles = await ProfileService.loadProfiles();

    expect(profiles.map((p) => p.credentials.secretAccessKey), [_secret, _secret]);
    expect(profiles.first.credentials.accessKeyId, 'AKIA1');
    expect(profiles.first.credentials.region, 'eu-west-1');

    final prefs = await SharedPreferences.getInstance();
    expect(await _prefsJson(), isNot(contains(_secret)));
    expect(await _prefsJson(), isNot(contains('AKIA')));
    expect(prefs.containsKey('aws_credentials'), isFalse);
    expect(await _keychainJson(), contains(_secret));

    // A second load reads the keys back from the Keychain alone.
    final reloaded = await ProfileService.loadProfiles();
    expect(reloaded.last.credentials.accessKeyId, 'AKIA2');
    expect(reloaded.last.credentials.secretAccessKey, _secret);
  });

  test('saving a profile never writes keys to preferences', () async {
    SharedPreferences.setMockInitialValues({});

    final profile = ProfileService.createProfile(
      name: 'Work',
      credentials: AwsCredentials(
        accessKeyId: 'AKIAWORK',
        secretAccessKey: _secret,
        region: 'ap-south-1',
        sessionToken: 'session-token',
      ),
    );
    await ProfileService.saveProfile(profile);
    await ProfileService.updateProfileLastUsed(profile.id);

    expect(await _prefsJson(), allOf(contains('Work'), contains('ap-south-1')));
    expect(await _prefsJson(), isNot(anyOf(contains(_secret), contains('AKIAWORK'), contains('session-token'))));

    final loaded = (await ProfileService.loadProfiles()).single;
    expect(loaded.credentials.secretAccessKey, _secret);
    expect(loaded.credentials.sessionToken, 'session-token');
  });

  test('deleting a profile removes its keys from the Keychain', () async {
    SharedPreferences.setMockInitialValues({
      'aws_profiles': jsonEncode([_legacyProfile('1'), _legacyProfile('2')]),
    });
    await ProfileService.loadProfiles();

    await ProfileService.deleteProfile('1');

    expect(await _keychainJson(), isNot(contains('AKIA1')));
    expect(await _keychainJson(), contains('AKIA2'));
  });

  test('a denied Keychain prompt becomes a plain-language error', () {
    final denied = KeychainException.from(
      PlatformException(code: 'Unexpected security result code', message: 'User canceled the operation.', details: -128),
      reading: true,
    );
    expect(denied.title, 'Keychain access was denied');
    expect(denied.message, contains('Always Allow'));
    expect(denied.message, contains('still safe'));

    final unknown = KeychainException.from(
      PlatformException(code: 'Unexpected security result code', message: 'Something odd.', details: -99999),
      reading: false,
    );
    expect(unknown.title, 'Could not save your keys');
    expect(unknown.message, contains('code -99999'));
  });
}
