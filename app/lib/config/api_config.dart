/// API configuration for the Waya backend (BFF).
///
/// The Flutter app talks to our backend, never directly to BMONI.
/// The backend holds the BMONI secret key and proxies all API calls.
class ApiConfig {
  ApiConfig._();

  /// Backend base URL — update for production
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const String apiVersion = '/api/v1';
}
