import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';
import 'schedule_planner.dart';
import 'token_store.dart';

/// Set by the app: called after a button press reached the server, so the
/// screens can refresh.
void Function()? onNotificationAnswered;

/// Sends the answer of a Taken/Skipped button to the server. Returns true when
/// the server accepted it. Works without the app's screens (no providers).
Future<bool> sendNotificationAnswer({
  required String? actionId,
  required String? payload,
  ApiClient? api,
  TokenStore? tokenStore,
  DateTime? now,
}) async {
  final target = answerFromTap(
    actionId: actionId,
    payload: payload,
    now: now ?? DateTime.now().toUtc(),
  );
  if (target == null) return false;
  try {
    final token = await (tokenStore ?? SecureTokenStore()).read();
    if (token == null) return false;
    await (api ?? ApiClient()).logSlot(
      token,
      reminderId: target.reminderId,
      scheduledFor: target.scheduledFor,
      status: target.status,
    );
    return true;
  } catch (e) {
    // Step 8 will keep such answers and send them later.
    debugPrint('Could not send the answer from the notification: $e');
    return false;
  }
}

/// A button was pressed while the app is closed or in the background.
/// Android runs this in its own isolate, so it must be a top-level function.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  await sendNotificationAnswer(
    actionId: response.actionId,
    payload: response.payload,
  );
}

/// A notification was tapped while the app is running.
void notificationTapHandler(NotificationResponse response) {
  unawaited(() async {
    final sent = await sendNotificationAnswer(
      actionId: response.actionId,
      payload: response.payload,
    );
    if (sent) onNotificationAnswered?.call();
  }());
}