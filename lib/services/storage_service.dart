import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/aws_credentials.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const _credentialsKey = 'aws_credentials';
  static bool _useSecureStorage = true;

  static Future<void> saveCredentials(AwsCredentials credentials) async {
    final credentialsJson = jsonEncode(credentials.toMap());
    
    if (_useSecureStorage) {
      try {
        await _storage.write(key: _credentialsKey, value: credentialsJson);
        return;
      } catch (e) {
        print('Secure storage failed, falling back to SharedPreferences: $e');
        _useSecureStorage = false;
      }
    }
    
    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_credentialsKey, credentialsJson);
  }

  static Future<AwsCredentials?> loadCredentials() async {
    String? credentialsJson;
    
    if (_useSecureStorage) {
      try {
        credentialsJson = await _storage.read(key: _credentialsKey);
      } catch (e) {
        print('Secure storage failed, falling back to SharedPreferences: $e');
        _useSecureStorage = false;
      }
    }
    
    // If secure storage failed or returned null, try SharedPreferences
    if (credentialsJson == null && !_useSecureStorage) {
      final prefs = await SharedPreferences.getInstance();
      credentialsJson = prefs.getString(_credentialsKey);
    }
    
    if (credentialsJson == null) return null;
    
    try {
      final credentialsMap = jsonDecode(credentialsJson);
      return AwsCredentials.fromMap(credentialsMap);
    } catch (e) {
      print('Failed to parse credentials: $e');
      return null;
    }
  }

  static Future<void> clearCredentials() async {
    if (_useSecureStorage) {
      try {
        await _storage.delete(key: _credentialsKey);
      } catch (e) {
        print('Secure storage delete failed: $e');
        _useSecureStorage = false;
      }
    }
    
    // Also clear from SharedPreferences as fallback
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_credentialsKey);
  }
}