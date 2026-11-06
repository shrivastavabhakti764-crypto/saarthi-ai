import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/app_user.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 10);
  static const _jsonHeaders = {'Content-Type': 'application/json'};

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  /// Sends a request, and returns the JSON object on success.
  /// Every failure becomes an [ApiException] with a message safe to show the user.
  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send,
  ) async {
    final http.Response response;
    try {
      response = await send().timeout(_timeout);
    } catch (_) {
      throw ApiException('Cannot reach the server. Check your connection.');
    }

    Object? decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw ApiException('Unexpected answer from the server.');
    }
    throw ApiException(
      _messageFor(response.statusCode, decoded),
      statusCode: response.statusCode,
    );
  }

  String _messageFor(int status, Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String) return detail;
      if (status == 422) return 'Please check the details you entered.';
    }
    return 'Something went wrong (code $status). Please try again.';
  }

  Future<Map<String, dynamic>> health() =>
      _request(() => _client.get(_uri('/health')));

  Future<AuthResult> register({
    required String name,
    required String phone,
    required String pin,
    required String role,
  }) async {
    final json = await _request(
      () => _client.post(
        _uri('/auth/register'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'pin': pin,
          'role': role,
        }),
      ),
    );
    return AuthResult.fromJson(json);
  }

  Future<AuthResult> login({
    required String phone,
    required String pin,
  }) async {
    final json = await _request(
      () => _client.post(
        _uri('/auth/login'),
        headers: _jsonHeaders,
        body: jsonEncode({'phone': phone, 'pin': pin}),
      ),
    );
    return AuthResult.fromJson(json);
  }

  Future<AppUser> me(String token) async {
    final json = await _request(
      () => _client.get(
        _uri('/me'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    return AppUser.fromJson(json);
  }
}