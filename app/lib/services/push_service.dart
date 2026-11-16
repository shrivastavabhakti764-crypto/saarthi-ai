import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../screens/alerts_screen.dart';
import 'api_client.dart';
import 'auth_provider.dart';

/// Lets the push service open a screen from outside the widget tree.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Starts Firebase, keeps the server's copy of this phone's push token up to
/// date for whoever is logged in, and opens Alerts when a push is tapped.
class PushService {
  PushService({required this.api, required this.auth});

  final ApiClient api;
  final AuthProvider auth;

  String? _sentFor; // the login token we last registered the push token for
  bool _openAlertsWhenReady = false;

  Future<void> start() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // The app works without push; reminders and chat do not depend on it.
      debugPrint('Push could not start: $e');
      return;
    }
    // ignore: deprecated_member_use
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      unawaited(_send(t));
    });
    // App was in the background and a push was tapped.
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _requestOpenAlerts());
    auth.addListener(_onAuthChanged);
    _onAuthChanged();
    // App was closed and a push was tapped to start it.
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _requestOpenAlerts();
    } catch (e) {
      debugPrint('Could not read the opening push: $e');
    }
  }

  void _requestOpenAlerts() {
    _openAlertsWhenReady = true;
    _openAlertsIfPossible();
  }

  void _openAlertsIfPossible() {
    if (!_openAlertsWhenReady) return;
    final user = auth.user;
    if (user == null) {
      // Still checking the saved login: wait. Not logged in: nothing to open.
      if (auth.restored) _openAlertsWhenReady = false;
      return;
    }
    _openAlertsWhenReady = false;
    if (!user.isNominee) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const AlertsScreen()),
      );
    });
  }

  void _onAuthChanged() {
    _openAlertsIfPossible();
    if (auth.token == null) {
      _sentFor = null;
      return;
    }
    if (auth.token == _sentFor) return;
    unawaited(_syncToken());
  }

  Future<void> _syncToken() async {
    try {
      // ignore: deprecated_member_use
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