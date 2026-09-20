# Feature Specification: Chat Experience and Reliability

**Status:** Approved — implementation in progress  
**Feature boundary:** `lib/features/conversations/`, `lib/navigation/rich_conversation_entry.dart`, `lib/services/notification_service.dart`, `scripts/conversations/`, `scripts/dispatch-notifications.js`, `specs/016-chat-experience-reliability/`

## Goal

Make ZaWolf chat fast, calm, familiar, and consistently branded while preserving server authorization, message history, idempotency, and existing delivery guarantees.

## User stories

### P0 — Fast, stable conversations

A user opens the inbox or a conversation and sees cached data immediately. A network refresh does not clear visible chats or messages. A single chat message commits once, uploads report meaningful progress, and the sender does not wait for push delivery.

**Acceptance criteria**

- Inbox and channel reuse the local cache immediately, then refresh in place without an empty-state flicker.
- Channel navigation performs one capability check and one authorized channel/timeline request; it does not open legacy departments or repeatedly rebuild listeners.
- Attachment creation, upload, finalize, and message commit expose separate progress/failure states. Independent selected attachments upload concurrently within a bounded limit; chunks for one file remain ordered and resumable.
- A single failed attachment has a retry action without resending already-completed attachments or duplicating the message.
- No message send waits for OneSignal delivery.
- A background notification title identifies the sender for a direct chat, or the group name for a group chat; its body contains the sender and message preview within the existing privacy policy.
- Upload state is persisted before transfer begins. Navigating to another chat never cancels it; foreground/background interruption resumes from the saved server offset when the app returns.

### P0 — Calm notification behavior

A user who is actively viewing a conversation receives no in-app toast, local alert, or device push for a new message in that conversation. Other conversations continue to notify normally. Muted and archived conversations create no user-facing notifications.

**Acceptance criteria**

- Notification documents retain deterministic per-message/per-recipient identity.
- When a recipient is active in a channel, that notification is read/suppressed before any toast or local notification is shown.
- Muting suppresses in-app and device alerts; archive also suppresses alerts until the conversation is restored.
- A new message from another conversation still notifies the user.
- Push failures caused by invalid OneSignal aliases close the provider retry safely and are observable as subscription-repair diagnostics, without causing duplicate notifications.

### P1 — Smart chat cache

The app keeps recent inbox entries, timelines, attachment metadata, and a bounded set of downloaded attachments locally so chat opens immediately without exposing stale data as current.

**Acceptance criteria**

- Cache records are scoped to the authenticated user, capped by count/size/age, and evicted least-recently-used.
- Cached inbox and messages render first; a refresh updates them in place.
- Attachment bytes are cached only after authorized download and are evicted before message metadata.
- Each attachment message always retains its server-authorized descriptor. If the user deletes a local media/file copy, the chat shows a clear **تنزيل** action that downloads the original again through the governed attachment endpoint.
- Deleting a local copy never deletes the chat message, the governed source file, or another participant’s copy. It removes only the current user’s cached bytes after confirmation.
- Cached images, voice notes, videos, and documents open immediately offline when their bytes are present. Missing local bytes show download state rather than a broken preview.
- Automatic cache eviction removes only local bytes according to user-configurable storage limits; message history and attachment descriptors remain available for re-download.
- Logout, account change, revoked conversation access, and explicit cache clear remove the affected local records.
- Offline mode clearly identifies cached content and never invents a successful send.

### P1 — WhatsApp-like conversation experience

Messages use compact directional bubbles: outgoing brand-blue bubbles on the RTL end, incoming dark-surface bubbles on the start, with a small tail, timestamp, delivery/read receipt, and attachment content inside the bubble. Long press retains existing governed message actions.

**Acceptance criteria**

- The brand accent derives from the wolf-logo blue/cyan palette. Semantic success, warning, and error colors remain distinct.
- Department-chat entry labels read **المحادثات**.
- Every back affordance follows RTL direction. The chat information sheet has a visible close/back control and can always be dismissed with the system back gesture.
- Mobile, web, Arabic RTL, offline, empty, pending upload, and failed upload states are supported.
- Messages are grouped with a centered date separator: **اليوم**, **أمس**, or
  a full Arabic weekday/date for older conversation history.

### P1 — Archive, mute, and swipe controls

A participant can swipe a direct-chat row to archive it. Archive is private to that participant, retains all history, hides the row from the default inbox, and suppresses notifications. The archived inbox lets the participant restore it. Receiving a new message does not automatically restore an archived chat unless the participant explicitly restores it.

**Acceptance criteria**

- Archive is server-authorized and stored per channel and participant; it never deletes messages or changes another participant’s inbox.
- Swipe confirmation provides archive and undo feedback.
- Archive writes are idempotent and a user can mute/unmute independently of archive.
- Archived rows do not appear in default direct inbox queries and are available from a clear archived view.

### P1 — Image paste

A pasted image is added to the composer as an attachment preview and follows the normal governed upload path.

**Platform constraint**

- Web image paste can be delivered in the Dart/web layer.
- Native Android and iOS raw-image clipboard access requires a platform plugin and therefore a store build. It cannot be delivered safely as a Shorebird/Dart-only patch. Until that build is shipped, mobile retains gallery, camera, and file-picker image selection.
- Continuing an upload while merely navigating inside the app is Dart patch-friendly. Continuing after the operating system backgrounds or terminates Android/iOS requires native background-transfer support and a store build; the durable outbox resumes automatically when the app next runs.

## Non-functional requirements

- Preserve channel access checks, attachment authorization, deterministic operation IDs, resumable per-file upload offsets, and existing 25 MB file limit.
- No Firestore-rule change or destructive migration. Preference documents are additive and server-owned.
- Bounded reads only: inbox pages stay at 50 and notification/activity checks are scoped to the active user/channel.
- New Cubits remain focused and under 300 lines.
- Existing conversations and notification preferences remain readable after rollout.

## Runtime findings to address

- Hostinger is running correctly; `another_worker_running` is a scheduler lease skip, not an error.
- The trace contains OneSignal `invalid_aliases` for some recipients. Those accounts are unsubscribed/invalid at OneSignal and require client re-registration; retries are already closed safely.
- Current rich-message notifications can be created for every message while a channel is open because the notification service has no active-channel suppression context.
- Current attachment delivery uploads selected files serially. Each upload is resumable, but serial upload makes multi-file sends unnecessarily slow.
- Existing notifications use generic titles; chat notification DTOs must carry the authorized sender and channel display context so direct and group titles are useful in the background.

## Success measures

- Cached inbox/channel content appears without an interim empty state.
- A single recipient sees zero alert surfaces for a message received while they are actively viewing that channel.
- One 1 MB attachment completes without duplicate message creation and with visibly advancing progress.
- Archive/mute affects only the current participant and produces zero notification alerts from that conversation.
