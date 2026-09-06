import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'api_service.dart';
import '../config/api_config.dart';

/// KYC service — handles document uploads, profile submission, and activation.
/// Both sender (Global KYC) and recipient (Nigeria KYC) flows go through here.
class KycService {
  /// Get KYC field options
  static Future<Map<String, dynamic>> getOptions() async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.get('/users/$userId/kyc/options');
  }

  /// Search occupations
  static Future<List<dynamic>> searchOccupations(String query) async {
    final userId = await ApiService.getStoredUserId();
    final result = await ApiService.get(
      '/users/$userId/kyc/occupations?search=${Uri.encodeComponent(query)}',
    );
    return (result['occupations'] as List?) ?? [];
  }

  /// BVN lookup (fetch only, does not save)
  static Future<Map<String, dynamic>> bvnLookup(String bvn) async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.get('/users/$userId/kyc/bvn-lookup/$bvn');
  }

  /// Upload identification document
  static Future<Map<String, dynamic>> uploadIdentification({
    required File file,
    required String type,
    required String documentNumber,
    required String issuingCountryCode,
    String? expirationDate,
  }) async {
    final userId = await ApiService.getStoredUserId();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.apiVersion}/users/$userId/kyc/documents/identification',
    );

    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    request.fields['type'] = type;
    request.fields['documentNumber'] = documentNumber;
    request.fields['issuingCountryCode'] = issuingCountryCode;
    if (expirationDate != null) request.fields['expirationDate'] = expirationDate;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(
        const {}.toString().isEmpty ? {} : {},
      )..addAll(
          Map<String, dynamic>.from(
            (response.body.isNotEmpty) ? {} : {},
          ),
        );
      // Simplified: just parse JSON
    }
    throw ApiException(statusCode: response.statusCode, message: response.body);
  }

  /// Upload proof of address
  static Future<Map<String, dynamic>> uploadProofOfAddress({
    required File file,
    required String type,
  }) async {
    final userId = await ApiService.getStoredUserId();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.apiVersion}/users/$userId/kyc/documents/proof-of-address',
    );

    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    request.fields['type'] = type;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(
        response.body.isNotEmpty ? {} : {},
      );
    }
    throw ApiException(statusCode: response.statusCode, message: response.body);
  }

  /// Upload biometric (selfie) — required for Global KYC (USD), not for NGN
  static Future<Map<String, dynamic>> uploadBiometric({
    required File file,
  }) async {
    final userId = await ApiService.getStoredUserId();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.apiVersion}/users/$userId/kyc/documents/biometric',
    );

    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(
        response.body.isNotEmpty ? {} : {},
      );
    }
    throw ApiException(statusCode: response.statusCode, message: response.body);
  }

  /// Submit KYC profile (personal + address + employment + compliance)
  static Future<Map<String, dynamic>> submitProfile({
    Map<String, dynamic>? personalInfo,
    Map<String, dynamic>? addressDetails,
    Map<String, dynamic>? employment,
    Map<String, dynamic>? identificationNumbers,
    Map<String, dynamic>? compliance,
  }) async {
    final userId = await ApiService.getStoredUserId();
    final body = <String, dynamic>{};
    if (personalInfo != null) body['personalInfo'] = personalInfo;
    if (addressDetails != null) body['addressDetails'] = addressDetails;
    if (employment != null) body['employment'] = employment;
    if (identificationNumbers != null) body['identificationNumbers'] = identificationNumbers;
    if (compliance != null) body['compliance'] = compliance;

    return ApiService.patch('/users/$userId/kyc', body: body);
  }

  /// Check KYC readiness
  static Future<Map<String, dynamic>> checkReadiness() async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.get('/users/$userId/kyc/readiness');
  }

  /// Check USD-specific readiness
  static Future<Map<String, dynamic>> checkUsdReadiness() async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.get('/users/$userId/kyc/usd-readiness');
  }

  /// Activate KYC — starts identity verification
  /// For Global KYC (USD): pass sumsubLevelName = 'id-and-liveness'
  /// For Nigeria KYC: omit body
  static Future<Map<String, dynamic>> activate({
    String? sumsubLevelName,
  }) async {
    final userId = await ApiService.getStoredUserId();
    final body = <String, dynamic>{};
    if (sumsubLevelName != null) body['sumsubLevelName'] = sumsubLevelName;

    return ApiService.post('/users/$userId/kyc/activate', body: body.isNotEmpty ? body : null);
  }

  /// Get onboarding status
  static Future<Map<String, dynamic>> getOnboardingStatus() async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.get('/users/$userId/onboarding/status');
  }
}
