import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/default_http_header.dart';

class DefaultHeadersService {
  static const String _key = 'default_http_headers';

  static Future<List<DefaultHttpHeader>> loadHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      if (jsonString == null) return [];
      
      final list = jsonDecode(jsonString) as List;
      return list.map((e) => DefaultHttpHeader.fromMap(e)).toList();
    } catch (e) {
      print('Failed to load default headers: $e');
      return [];
    }
  }

  static Future<void> saveHeaders(List<DefaultHttpHeader> headers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(headers.map((e) => e.toMap()).toList());
      await prefs.setString(_key, jsonString);
    } catch (e) {
      print('Failed to save default headers: $e');
    }
  }
}
