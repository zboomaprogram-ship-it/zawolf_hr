# Implementation Plan: Chat Experience and Reliability

**Spec:** [spec.md](spec.md)  
**Status:** Approved — implementation in progress

## Delivery slices

1. **Reliability and notification calm**
   - Add active-channel presence to the notification service and suppress/mark-read matching chat events before toast/local notification delivery.
   - Store archive state locally per user/device and use the existing server-side
     `enabled` preference to mute the archived direct conversation.
   - Keep archive removal reversible from a future archive view; new messages
     remain durable and are not deleted by archiving.
   - Add OneSignal subscription-repair diagnostics and avoid retrying invalid aliases.
   - Compose background notification titles from the authorized direct sender or group name, with sender/message preview in the body.

2. **Inbox and navigation performance**
   - Keep cached inbox/channel state visible while polling refreshes.
   - Deduplicate repository stream ownership and navigation bootstrap work.
   - Replace global conversation scans with member/participant-aware bounded query paths or a server-owned per-user inbox projection, selected after read-budget testing.
   - Add an explicit close control to chat information and verify all RTL back paths.

3. **Attachment delivery and composer**
   - Retain ordered resumable chunks for each resource.
   - Add bounded parallel upload of independent selected resources and per-file progress/retry state.
   - Persist upload jobs and offsets in the outbox so navigation cannot cancel transfers; resume interrupted jobs from the server-confirmed offset.
   - Add web clipboard-image ingestion into the existing `ChatDraftFile` path.
   - Keep native image clipboard as a separately packaged store-build increment.

4. **Smart cache**
   - Define a user-scoped cache policy for inboxes, timelines, attachment descriptors, and downloaded bytes.
   - Render cached images, voice notes, video, and documents locally when available; otherwise retain the server attachment descriptor and show a governed re-download action.
   - Add local-copy deletion that removes only cached bytes after confirmation, preserving the message and remote governed media for later download.
   - Implement time-to-live, size limits, LRU eviction, refresh-in-place, logout cleanup, access-revocation cleanup, and a user-visible storage setting.

5. **Visual system and WhatsApp-style bubbles**
   - Establish logo-derived brand blue tokens and replace only non-semantic blue/cyan accents through theme tokens.
   - Restyle bubbles, receipts, tails, attachment cards, composer, and inbox rows within the conversations feature.
   - Rename user-facing department-chat labels to **المحادثات**.
   - Add direct-chat swipe archive, undo, and archived inbox entry.

## Architecture

- `domain`: add an archive/mute preference contract and active channel alert-suppression contract.
- `data`: repository implements contracts via existing authenticated conversation transport and local store.
- `presentation`: focused preference/archive Cubit; inbox and timeline Cubits remain below 300 lines.
- `scripts/conversations`: server authorizes all preference mutations and computes inbox visibility. `dispatch-notifications.js` respects the same preference.

## Rollout and rollback

- New preference documents are additive. Missing preference preserves current visible/unmuted behavior.
- Roll out archive and active-channel suppression behind a conversation feature flag if the existing rich-chat flag cannot scope this safely.
- Rollback disables the new read path; conversation and message history remain unchanged.
- Flutter visual, archive, cache, upload-resume-on-navigation, and web-paste changes are Dart patch-friendly. Hostinger changes require a deployment ZIP. Native mobile clipboard image support and continued uploads while Android/iOS is backgrounded or terminated require a store build.

## Validation

- Flutter: inbox cache/no-flicker, active-chat no-alert, archive/mute, RTL back/info close, bubble semantics, attachment progress/retry, web paste contract.
- Node: authorization, preference idempotency, archive filtering, muted/archived dispatch suppression, exact notification identity, bounded upload concurrency.
- Run `flutter analyze`, architecture/query guards, full Flutter tests, and `scripts/npm test`.
