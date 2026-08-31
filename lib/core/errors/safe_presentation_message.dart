/// Guards an app-authored business message before it reaches a user interface.
///
/// Provider exception strings are diagnostics, not presentation content. This
/// keeps Arabic guidance that our application deliberately throws while
/// rejecting Firebase/network/stack details that must never be displayed.
String? safeArabicBusinessMessage(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  if (message.isEmpty || !RegExp(r'[\u0600-\u06FF]').hasMatch(message)) {
    return null;
  }

  const unsafeFragments = <String>[
    'cloud_firestore',
    'firebase_auth',
    'firebase',
    'permission-denied',
    'unavailable',
    'failed-precondition',
    'http',
    'exception',
    'stack trace',
    'typeerror',
  ];
  final normalized = message.toLowerCase();
  return unsafeFragments.any(normalized.contains) ? null : message;
}
