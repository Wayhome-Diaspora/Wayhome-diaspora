import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// HTTP client for the Waya backend.
/// All BMONI API calls go through our backend — never directly from the client.
class ApiService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'bmoni_user_id';

  /// Get stored BMONI user ID
  static Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Save BMONI user ID
  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  /// Clear stored session
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  /// Make a POST request to the backend
  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.apiVersion}$path');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: response.body,
    );
  }

  /// Make a GET request to the backend
  static Future<Map<String, dynamic>> get(String path) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.apiVersion}$path');
    final response = await http.get(url, headers: {'Content-Type': 'application/json'});

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: response.body,
    );
  }

  /// Make a PATCH request to the backend
  static Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.apiVersion}$path');
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: response.body,
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
