import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A failure of the secure key store (the Keychain on macOS, DPAPI on
/// Windows), worded for the user rather than as a status code.
class KeychainException implements Exception {
  final String title;
  final String message;
  final int? status;

  const KeychainException(this.title, this.message, {this.status});

  static String get _storeName => Platform.isMacOS ? 'the macOS Keychain' : 'Windows secure storage';

  /// For errors that aren't a PlatformException, e.g. the Windows plugin's
  /// WindowsException or FileSystemException.
  factory KeychainException.other(Object e, {required bool reading}) {
    return KeychainException(
      reading ? 'Could not read your saved keys' : 'Could not save your keys',
      'Hoistbay could not ${reading ? 'read from' : 'write to'} $_storeName: $e',
    );
  }

  factory KeychainException.from(PlatformException e, {required bool reading}) {
    final status = e.details is int ? e.details as int : null;
    switch (status) {
      case -128: // errSecUserCanceled
      case -25293: // errSecAuthFailed
        return KeychainException(
          'Keychain access was denied',
          reading
              ? 'Hoistbay needs permission to read your saved AWS keys from the macOS Keychain. '
                  'Your keys are still safe there. Choose Try Again, then click "Always Allow" when macOS asks.'
              : 'Hoistbay needs permission to save your AWS keys in the macOS Keychain, so nothing was saved. '
                  'Try again and click "Always Allow" when macOS asks.',
          status: status,
        );
      case -25308: // errSecInteractionNotAllowed
        return KeychainException(
          'Your Keychain is locked',
          'Unlock your login keychain (or log in to your Mac again), then try again.',
          status: status,
        );
      default:
        return KeychainException(
          reading ? 'Could not read your saved keys' : 'Could not save your keys',
          '${_storeName[0].toUpperCase()}${_storeName.substring(1)} returned an error: ${e.message ?? e.code}'
              '${status != null ? ' (code $status)' : ''}.',
          status: status,
        );
    }
  }

  @override
  String toString() => '$title. $message';
}

/// Holds every profile's secrets (access key ID, secret key, session token)
/// in the macOS Keychain; the rest of a profile lives in SharedPreferences.
///
/// All profiles share one Keychain item, so when an app update changes the
/// code signature macOS asks for access once rather than once per profile.
/// There is deliberately no plaintext fallback: if the Keychain fails, the
/// error reaches the user instead of the keys landing on disk.
class CredentialStore {
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(
      // The data protection keychain needs a keychain-access-groups
      // entitlement, which needs a team-signed build. Hoistbay ships ad-hoc
      // signed, so use the login keychain: its item ACL trusts only the app
      // that created the item, and any other process gets a Keychain prompt.
      usesDataProtectionKeychain: false,
    ),
  );
  static const _secretsKey = 'aws_profile_secrets';

  // Startup and the profile list both load at launch; sharing one read means
  // macOS shows one Keychain prompt rather than two.
  static Future<Map<String, Map<String, dynamic>>>? _pendingLoad;

  /// Secrets keyed by profile ID.
  static Future<Map<String, Map<String, dynamic>>> loadAll() async {
    final secrets = await (_pendingLoad ??= _loadAll().whenComplete(() => _pendingLoad = null));
    // Each caller gets its own map, since ProfileService adds to it.
    return {...secrets};
  }

  static Future<Map<String, Map<String, dynamic>>> _loadAll() async {
    final String? json;
    try {
      json = await _storage.read(key: _secretsKey);
    } on PlatformException catch (e) {
      throw KeychainException.from(e, reading: true);
    } catch (e) {
      throw KeychainException.other(e, reading: true);
    }
    if (json == null) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((id, secrets) => MapEntry(id, Map<String, dynamic>.from(secrets as Map)));
  }

  static Future<void> saveAll(Map<String, Map<String, dynamic>> secrets) async {
    try {
      await _storage.write(key: _secretsKey, value: jsonEncode(secrets));
    } on PlatformException catch (e) {
      throw KeychainException.from(e, reading: false);
    } catch (e) {
      throw KeychainException.other(e, reading: false);
    }
  }
}
