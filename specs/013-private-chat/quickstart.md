# Validation Guide: Governed Private Chat

## Prerequisites

- Rich chat enabled for each test actor.
- Active fixtures for ordinary employee, manager, HR, super administrator, IT employee, and a manager from another department.
- A direct manager relationship for the ordinary employee.

## Authorization validation

1. Sign in as the ordinary employee; choose a department and verify eligible ordinary employees.
2. Verify the direct manager, HR, super administrator, and IT sections appear and are selectable.
3. Verify an unassigned manager from another department is absent; call the direct-create contract with that ID and expect `access_denied`.
4. Sign in as a manager and then a super administrator; verify each can start chats with all active fixtures.
5. Deactivate a target and verify it disappears and cannot be used through a stale request.

## Inbox validation

1. Create a direct conversation and send a message; verify it appears only in Private chats.
2. Open department, manager, and custom groups; verify they appear only in Groups.
3. Send messages in three conversations in a controlled sequence; refresh on mobile and web and verify newest-first order.
4. Start the same direct chat from two clients at once; verify one conversation ID and one inbox row.
5. Load multiple pages, receive a new message, and verify no duplicate and correct top placement.

## Required automated checks

```bash
flutter analyze
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test
(cd scripts && npm test)
```

## Native notification-sound release check

`notification_chime.wav` is a two-second derivative of the licensed ZaWolf
alarm. It is packaged in both Android and iOS native resources and selected by
the push payload. It requires an Android/iOS store update; do not attempt to
ship it through a Dart or Shorebird patch. Verify one foreground, background,
and terminated chat notification on each platform after the store build is
installed. Older clients fall back to their platform default sound.
