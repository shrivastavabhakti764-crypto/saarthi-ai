import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';
import 'pending_answers.dart';
import 'schedule_planner.dart';
import 'token_store.dart';

/// Set by the app: called after a button press reached the server, so the
/// screens can refresh.
void Function()? onNotificationAnswered;

/// A failure that may go away later: no internet, a server error, or a login
/// token the server does not accept right now. Anything else (like "not a
/// scheduled time") will never work, so such answers are not kept.
bool _isTemporary(ApiException e) {
  final code = e.statusCode;
  return code == null || code >= 500 || code == 401;
}

/// Sends the answer of a Taken/Skipped button to the server. Returns true when
/// the server accepted it. If the server could not be reached, the answer is
/// kept to be sent later. Works without the app's screens (no providers).
Future<bool> sendNotificationAnswer({
  required String? actionId,
  required String? payload,
  ApiClient? api,
  TokenStore? tokenStore,
  PendingAnswerStore? pending,
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
  } on ApiException catch (e) {
    if (_isTemporary(e)) {
      try {
        await (pending ?? SecurePendingAnswerStore()).add(
          PendingAnswer(
            reminderId: target.reminderId,
            scheduledFor: target.scheduledFor,
            status: target.status,
          ),
        );
      } catch (error) {
        debugPrint('Could not keep the answer for later: $error');
      }
    }
    return false;
  } catch (e) {
    debugPrint('Could not send the answer from the notification: $e');
    return false;
  }
}

/// Sends the answers that were kept while the server was out of reach.
/// Returns how many the server accepted. Stops at the first temporary failure
/// and keeps the rest for next time.
Future<int> flushPendingAnswers({
  ApiClient? api,
  TokenStore? tokenStore,
  PendingAnswerStore? pending,
}) async {
  final store = pending ?? SecurePendingAnswerStore();
  final client = api ?? ApiClient();
  var sent = 0;
  try {
    final token = await (tokenStore ?? SecureTokenStore()).read();
    if (token == null) return 0;
    for (final answer in await store.all()) {
      try {
        await client.logSlot(
          token,
          reminderId: answer.reminderId,
          scheduledFor: answer.scheduledFor,
          status: answer.status,
        );
        await store.remove(answer);
        sent++;
      } on ApiException catch (e) {
        if (_isTemporary(e)) break;
        await store.remove(answer); // the server will never accept it
      }
    }
  } catch (e) {
    debugPrint('Could not send the kept answers: $e');
  }
  return sent;
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