import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_provider.dart';

/// Starts Firebase and keeps the server's copy of this phone's push token
/// up to date for whoever is logged in.
class PushService {
  PushService({required this.api, required this.auth});

  final ApiClient api;
  final AuthProvider auth;

  String? _sentFor; // the login token we last registered the push token for

  Future<void> start() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // The app works without push; reminders and chat do not depend on it.
      debugPrint('Push could not start: $e');
      return;
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      unawaited(_send(t));
    });
    auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    if (auth.token == null) {
      _sentFor = null;
      return;
    }
    if (auth.token == _sentFor) return;
    unawaited(_syncToken());
  }

  Future<void> _syncToken() async {
    try {
      final fcm = await FirebaseMessaging.instance.getToken();
      if (fcm != null) await _send(fcm);
    } catch (e) {
      debugPrint('Push token not available: $e');
    }
  }

  Future<void> _send(String fcm) async {
    final loginToken = auth.token;
    if (loginToken == null) return;
    try {
      await api.saveFcmToken(loginToken, fcm);
      _sentFor = loginToken;
    } catch (e) {
      debugPrint('Push token not saved: $e');
    }
  }
}