import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/app_user.dart';
import '../models/link.dart';

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

  Map<String, String> _bearer(String token) =>
      {'Authorization': 'Bearer $token'};

  /// Sends a request and returns the decoded JSON (null when the body is empty).
  /// Every failure becomes an [ApiException] with a message safe to show the user.
  Future<Object?> _send(Future<http.Response> Function() send) async {
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
      return decoded;
    }
    throw ApiException(
      _messageFor(response.statusCode, decoded),
      statusCode: response.statusCode,
    );
  }

  /// Like [_send], for endpoints that answer with a JSON object.
  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send,
  ) async {
    final decoded = await _send(send);
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException('Unexpected answer from the server.');
  }

  /// Like [_send], for endpoints that answer with a JSON list.
  Future<List<dynamic>> _requestList(
    Future<http.Response> Function() send,
  ) async {
    final decoded = await _send(send);
    if (decoded is List<dynamic>) return decoded;
    throw ApiException('Unexpected answer from the server.');
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
      () => _client.get(_uri('/me'), headers: _bearer(token)),
    );
    return AppUser.fromJson(json);
  }

  Future<AppUser> acceptConsent(String token) async {
    final json = await _request(
      () => _client.post(_uri('/me/consent'), headers: _bearer(token)),
    );
    return AppUser.fromJson(json);
  }

  Future<LinkCode> createLinkCode(String token) async {
    final json = await _request(
      () => _client.post(_uri('/links/code'), headers: _bearer(token)),
    );
    return LinkCode.fromJson(json);
  }

  Future<LinkInfo> redeemLinkCode(
    String token, {
    required String code,
    required String relationship,
    String? whatsappNumber,
    bool whatsappOptIn = false,
  }) async {
    final json = await _request(
      () => _client.post(
        _uri('/links/redeem'),
        headers: {..._jsonHeaders, ..._bearer(token)},
        body: jsonEncode({
          'code': code,
          'relationship': relationship,
          'whatsapp_number': whatsappNumber,
          'whatsapp_opt_in': whatsappOptIn,
        }),
      ),
    );
    return LinkInfo.fromJson(json);
  }

  Future<List<LinkInfo>> listLinks(String token) async {
    final list = await _requestList(
      () => _client.get(_uri('/links'), headers: _bearer(token)),
    );
    return list
        .map((item) => LinkInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> unlink(String token, int linkId) async {
    await _send(
      () => _client.delete(_uri('/links/$linkId'), headers: _bearer(token)),
    );
  }
}