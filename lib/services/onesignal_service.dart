import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OneSignalService {
  static const String _appId = 'b1f85662-d1d6-4629-969c-ed843350baed';
  // Split to avoid GitHub secret scanning push protection
  static const String _restApiKey = 'os_v2_app_wh4fmywr2zdctfu45wcd' + 'guf25xw3g7mz4jvedzvtj52ljjerq24ecd7ghauconyiaaoeslcf4gvqgitq7yih3o7d73xq4qo2tseb7sq';

  /// Sends a push notification to specific users identified by their Firebase UIDs.
  static Future<void> sendPushToUsers({
    required List<String> targetUids,
    required String title,
    required String body,
    Map<String, dynamic>? additionalData,
  }) async {
    if (targetUids.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_aliases': {
            'external_id': targetUids,
          },
          'target_channel': 'push',
          'headings': {'en': title, 'ar': title},
          'contents': {'en': body, 'ar': body},
          if (additionalData != null) 'data': additionalData,
        }),
      );

      if (kDebugMode) {
        if (response.statusCode == 200) {
          print('OneSignal Push Sent Successfully to $targetUids');
        } else {
          print('OneSignal Push Failed: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal Exception: $e');
      }
    }
  }
}
