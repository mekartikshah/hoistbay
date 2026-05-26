import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/aws_profile.dart';
import '../models/aws_credentials.dart';

class ProfileService {
  static const String _profilesKey = 'aws_profiles';
  static const String _currentProfileKey = 'current_profile_id';

  static Future<List<AwsProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_profilesKey);
    
    if (profilesJson == null) return [];
    
    try {
      final profilesList = jsonDecode(profilesJson) as List;
      return profilesList.map((profile) => AwsProfile.fromMap(profile)).toList();
    } catch (e) {
      print('Failed to load profiles: $e');
      return [];
    }
  }

  static Future<void> saveProfiles(List<AwsProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = jsonEncode(profiles.map((profile) => profile.toMap()).toList());
    await prefs.setString(_profilesKey, profilesJson);
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
      await saveProfiles(profiles);
    }
  }
}

extension IterableExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}