import 'package:flutter/foundation.dart';

import '../models/link.dart';
import 'api_client.dart';
import 'auth_provider.dart';

/// Who is linked to whom, plus the senior's current link code.
class LinksProvider extends ChangeNotifier {
  LinksProvider({required this._api, required this._auth}) {
    _auth.addListener(_onAuthChanged);
  }

  final ApiClient _api;
  final AuthProvider _auth;

  List<LinkInfo> _links = const [];
  LinkCode? _code;
  bool _loading = false;
  String? _error;

  List<LinkInfo> get links => _links;
  LinkCode? get code => _code;
  bool get loading => _loading;
  String? get error => _error;

  String _token() {
    final token = _auth.token;
    if (token == null) throw ApiException('Please log in again.');
    return token;
  }

  /// When the user logs out, forget everything about their links.
  void _onAuthChanged() {
    if (!_auth.isLoggedIn && (_links.isNotEmpty || _code != null)) {
      _links = const [];
      _code = null;
      _error = null;
      notifyListeners();
    }
  }

  /// Reloads the list. A failure is kept in [error] so a screen can show it.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _links = await _api.listLinks(_token());
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Senior: ask the server for a new 6-digit code.
  Future<LinkCode> createCode() async {
    final code = await _api.createLinkCode(_token());
    _code = code;
    notifyListeners();
    return code;
  }

  /// Nominee: use a senior's code. Throws [ApiException] if the code is wrong.
  Future<LinkInfo> redeem({
    required String code,
    required String relationship,
    String? whatsappNumber,
    bool whatsappOptIn = false,
  }) async {
    final link = await _api.redeemLinkCode(
      _token(),
      code: code,
      relationship: relationship,
      whatsappNumber: whatsappNumber,
      whatsappOptIn: whatsappOptIn,
    );
    _links = [..._links, link];
    notifyListeners();
    return link;
  }

  Future<void> unlink(int linkId) async {
    await _api.unlink(_token(), linkId);
    _links = _links.where((link) => link.id != linkId).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}