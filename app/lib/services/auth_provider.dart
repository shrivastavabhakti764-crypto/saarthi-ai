import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'api_client.dart';
import 'token_store.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({required this._api, required this._tokenStore});

  final ApiClient _api;
  final TokenStore _tokenStore;

  AppUser? _user;
  String? _token;
  bool _restored = false;

  AppUser? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _user != null;

  /// True once the saved token has been checked at app start.
  bool get restored => _restored;

  /// Called once at app start: if a token is saved and still valid, log in silently.
  Future<void> restoreSession() async {
    final saved = await _tokenStore.read();
    if (saved != null) {
      try {
        _user = await _api.me(saved);
        _token = saved;
      } on ApiException catch (e) {
        // Only an explicit "unauthorized" means the token is useless.
        // A network error keeps it, so the next launch can try again.
        if (e.statusCode == 401) await _tokenStore.clear();
      }
    }
    _restored = true;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String phone,
    required String pin,
    required String role,
  }) async {
    final result = await _api.register(
      name: name,
      phone: phone,
      pin: pin,
      role: role,
    );
    await _signIn(result);
  }

  Future<void> login({required String phone, required String pin}) async {
    final result = await _api.login(phone: phone, pin: pin);
    await _signIn(result);
  }

  Future<void> logout() async {
    await _tokenStore.clear();
    _user = null;
    _token = null;
    notifyListeners();
  }

  Future<void> _signIn(AuthResult result) async {
    await _tokenStore.save(result.token);
    _token = result.token;
    _user = result.user;
    notifyListeners();
  }
}