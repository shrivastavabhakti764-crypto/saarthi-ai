import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

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

  Future<Map<String, dynamic>> health() async {
    try {
      final response = await _client
          .get(Uri.parse('${AppConfig.apiBaseUrl}/health'))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw ApiException(
          'Server answered ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Cannot reach the server. Check your connection.');
    }
  }
}