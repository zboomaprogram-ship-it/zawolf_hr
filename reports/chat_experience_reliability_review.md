# Chat Experience and Reliability Review

**Reviewed:** 2026-09-20  
**Scope:** Changes currently present in the working tree for `specs/016-chat-experience-reliability`.

## Implemented and verified

- Cached inbox/timeline data remains visible while polling refreshes.
- The rich-chat entry no longer opens each legacy department at startup.
- Selected attachments now upload with at most three files in parallel; chunks of each file remain ordered and resumable.
- The outbox retains selected bytes and resumes delivery when that channel is reopened.
- Downloaded attachment bytes are persisted locally per user/channel with a 64 MB per-channel LRU budget. The original governed attachment endpoint remains the re-download source.
- The composer supports web image paste through `ContentInsertionConfiguration`.
- Outgoing/incoming bubble colors and corner shapes are clearer, and visible labels use **المحادثات**.
- Chat information has a visible close button and the regular chat back path remains RTL-aware.
- Notification titles now use the direct sender name or group name; group previews include the sender.
- While a rich-chat page is active, matching notification documents are marked read before local/in-app alerts are emitted.
- A direct conversation can be swiped away locally and is muted with an immediate Undo action.

Focused conversation tests, architecture/query guards, full Flutter tests, and Node tests passed on 2026-09-17 during the implementation run.

## Gaps that remain before the feature can be called complete

1. **Archive is local, not a complete WhatsApp-style archive.** The current implementation hides a direct row on this device and mutes it through the existing server preference. It does not provide an archived-chat list or durable server-side archive state. A user can undo immediately, but there is no later archive management screen.
2. **Open-chat notification suppression cannot reliably prevent an already-dispatched OneSignal push.** The client suppresses local/in-app alerts after the Firestore notification arrives. The Hostinger dispatcher has no active-channel presence signal, so a device push may already have been sent. Server presence/acknowledgement is required for the stated zero-push guarantee.
3. **The inbox query remains the main latency risk.** It still reads an ordered global conversation page, filters authorization in the runtime, and calculates unread counts by inspecting recent messages. Cached rendering masks this delay but does not remove the backend work. The planned member-aware query or per-user inbox projection is not implemented.
4. **The cache does not yet meet the full smart-cache specification.** It has persisted LRU media bytes, but no TTL, global storage settings, clear-cache screen, explicit local-copy delete confirmation, or logout/access-revocation cleanup.
5. **Background transfer has a platform limit.** In-app navigation retains/resumes uploads. Android/iOS may suspend or terminate Dart work in the background; a native background-transfer implementation and store build are needed for reliable OS-background uploads.
6. **Per-file upload retry UI is not separate yet.** The durable message retry reuses completed server state, but the UI does not expose independent retry controls for a single failed selected attachment.
7. **OneSignal invalid aliases are observed but not repaired.** The server logs correctly identify unsubscribed aliases; client re-registration/subscription repair is not included in the current change.
8. **Specification bookkeeping is inconsistent.** `plan.md` was changed to approved/in progress while `spec.md` and `tasks.md` still say review/awaiting review. This should be reconciled before deployment.

## Recommended next increment

Complete the server-owned active-channel presence and bounded inbox projection first. It addresses the reported 30-second open time and repeated notifications without relying on client timing. Then add the archive list, cache controls, and native background-transfer release as separate reviewed increments.
