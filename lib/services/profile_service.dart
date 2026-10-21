import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/aws_profile.dart';
import '../models/aws_credentials.dart';
import 'credential_store.dart';

/// Profile names, regions and timestamps live in SharedPreferences; the keys
/// themselves live in the Keychain via [CredentialStore].
class ProfileService {
  static const String _profilesKey = 'aws_profiles';
  static const String _currentProfileKey = 'current_profile_id';
  // Plaintext credentials left by an older, removed StorageService fallback.
  static const String _legacyCredentialsKey = 'aws_credentials';
  static const List<String> _secretFields = ['accessKeyId', 'secretAccessKey', 'sessionToken'];

  static Future<List<AwsProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_legacyCredentialsKey)) {
      await prefs.remove(_legacyCredentialsKey);
    }
    final profilesJson = prefs.getString(_profilesKey);

    if (profilesJson == null) return [];

    final List<Map<String, dynamic>> profileMaps;
    try {
      profileMaps = (jsonDecode(profilesJson) as List)
          .map((profile) => Map<String, dynamic>.from(profile as Map))
          .toList();
    } catch (e) {
      print('Failed to load profiles: $e');
      return [];
    }

    final secrets = await CredentialStore.loadAll();

    // Older versions kept keys in SharedPreferences. Move them into the
    // Keychain, and only strip them from disk once the Keychain write worked.
    final plaintext = {
      for (final map in profileMaps)
        if (_hasSecrets(map)) map['id'] as String: _secretsOf(map),
    };
    if (plaintext.isNotEmpty) {
      secrets.addAll(plaintext);
      await CredentialStore.saveAll(secrets);
      await _saveMetadata(profileMaps);
    }

    return profileMaps.map((map) {
      final credentials = {
        ...Map<String, dynamic>.from(map['credentials'] ?? {}),
        ...?secrets[map['id']],
      };
      return AwsProfile.fromMap({...map, 'credentials': credentials});
    }).toList();
  }

  static Future<void> saveProfiles(List<AwsProfile> profiles) async {
    // Keychain first: if it fails, nothing new is written in plaintext.
    await CredentialStore.saveAll({
      for (final profile in profiles) profile.id: _secretsOf(profile.toMap()),
    });
    await _saveMetadata(profiles.map((profile) => profile.toMap()).toList());
  }

  /// Writes profiles to SharedPreferences with every secret field removed.
  static Future<void> _saveMetadata(List<Map<String, dynamic>> profileMaps) async {
    final prefs = await SharedPreferences.getInstance();
    final stripped = profileMaps.map((map) {
      final credentials = Map<String, dynamic>.from(map['credentials'] ?? {})
        ..removeWhere((field, _) => _secretFields.contains(field));
      return {...map, 'credentials': credentials};
    }).toList();
    await prefs.setString(_profilesKey, jsonEncode(stripped));
  }

  static bool _hasSecrets(Map<String, dynamic> profileMap) {
    final credentials = profileMap['credentials'];
    return credentials is Map && _secretFields.any(credentials.containsKey);
  }

  static Map<String, dynamic> _secretsOf(Map<String, dynamic> profileMap) {
    final credentials = Map<String, dynamic>.from(profileMap['credentials'] ?? {});
    return {for (final field in _secretFields) field: credentials[field]};
  }

  static Future<AwsProfile> saveProfile(AwsProfile profile) async {
    final profiles = await loadProfiles();
    
    // Update existing profile or add new one
    final existingIndex = profiles.indexWhere((p) => p.id == profile.id);
    if (existingIndex >= 0) {
      profiles[existingIndex] = profile;
    } else {
      profiles.add(profile);
    }
    
    await saveProfiles(profiles);
    return profile;
  }

  static Future<void> deleteProfile(String profileId) async {
    final profiles = await loadProfiles();
    profiles.removeWhere((profile) => profile.id == profileId);
    await saveProfiles(profiles);
    
    // Clear current profile if it was deleted
    final currentProfileId = await getCurrentProfileId();
    if (currentProfileId == profileId) {
      await setCurrentProfile(null);
    }
  }

  static Future<void> setCurrentProfile(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    if (profileId == null) {
      await prefs.remove(_currentProfileKey);
    } else {
      await prefs.setString(_currentProfileKey, profileId);
    }
  }

  static Future<String?> getCurrentProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentProfileKey);
  }

  static Future<AwsProfile?> getCurrentProfile() async {
    final currentProfileId = await getCurrentProfileId();
    if (currentProfileId == null) return null;
    
    final profiles = await loadProfiles();
    return profiles.where((profile) => profile.id == currentProfileId).firstOrNull;
  }

  static String generateProfileId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  static AwsProfile createProfile({
    required String name,
    required AwsCredentials credentials,
  }) {
    final now = DateTime.now();
    return AwsProfile(
      id: generateProfileId(),
      name: name,
      credentials: credentials,
      createdAt: now,
      lastUsed: now,
    );
  }

  static Future<void> updateProfileLastUsed(String profileId) async {
    final profiles = await loadProfiles();
    final profileIndex = profiles.indexWhere((p) => p.id == profileId);

    if (profileIndex >= 0) {
      profiles[profileIndex] = profiles[profileIndex].copyWith(
        lastUsed: DateTime.now(),
      );
      // Only the timestamp changed, so leave the Keychain item alone.
      await _saveMetadata(profiles.map((profile) => profile.toMap()).toList());
    }
  }
}

extension IterableExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}