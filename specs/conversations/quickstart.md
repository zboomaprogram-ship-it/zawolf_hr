# Validation Guide: Zawolf Chat Upgrade (Rich Chat V1)

**Feature**: Zawolf Chat Upgrade  
**Location**: `specs/conversations/quickstart.md`  
**Governing Standard**: `specs/conversations/spec.md`, `.specify/memory/constitution.md`

---

## 1. Preconditions & Test Environment

1. **Environment**: Non-production Firebase project and Hostinger staging router (`https://notification.zawolf.ai`).
2. **Actor Personas**:
   - `EMP-TEST-01`: Standard employee (Engineering department).
   - `EMP-TEST-02`: Standard employee (Marketing department).
   - `MGR-TEST-01`: Direct manager for Engineering.
   - `HR-TEST-01`: Canonical HR / Administrator role (`isHrOrAdmin == true`).
3. **Target Platforms**:
   - **Web Browsers**: Google Chrome, Brave (Chromium desktop engines).
   - **Mobile Devices**: iOS and Android.
   - **Desktop Runtimes**: Linux and Windows (in addition to macOS development target).
4. **Rollout Control**:
   - Controlled via `PHASE007_FEATURE_FLAGS_JSON` on the Hostinger server environment or via `scripts/feature-flags.js`.
   - Feature flag: `conversations_rich_chat_v1`.
   - Client verifies flag dynamically on boot via `GET /conversations/v2/capabilities`.

---

## 2. Acceptance Verification Matrix

### 2.1 Send Reliability & Outbox Durability
| # | Scenario | Steps to Execute | Expected Result |
|---|---|---|---|
| 1 | Text-Only Send | Compose a 50-character Arabic text message and send. | Message appears immediately with optimistic spinner, transitions to `sent` upon server 200 OK. |
| 2 | Attachment-Only Send | Pick a 5 MiB PDF, leave text composer completely blank, tap send. | Upload completes, message created with zero synthetic `مرفق` text. Caption is empty. |
| 3 | Historical Caption Masking | Open channel with historical legacy message containing `مرفق` and attachment. | Timeline suppresses `مرفق` text; renders attachment preview cleanly. |
| 4 | Interrupted Chunk Upload | Begin uploading a 15 MiB file; simulate network drop at 7 MiB. | Upload pauses; client shows `failed` with retry button. Calling `GET /uploads/{id}` confirms 7 MiB offset. Tap retry: upload resumes from 7 MiB and completes. |
| 5 | App Crash / Restart Recovery | Queue a message with attachments; forcefully terminate app process mid-flight. | Relaunch app: draft and pending outbox operation are restored from Drift database. Background coordinator resumes upload. |
| 6 | Idempotent Retry | Transmit identical send payload twice with same `operationId`. | Server acknowledges first request, replays original response on second; exactly one message document exists in Firestore. |
| 7 | Max Size Enforcement | Select a 25.1 MiB file (exceeding 26,214,400 bytes). | Client picker rejects file immediately with Arabic error dialog; zero network transfer initiated. |
| 8 | Max Attachment Count | Attempt to select 11 files simultaneously. | Client rejects selection; alerts user that maximum 10 attachments are allowed per message. |
| 9 | Max Text Length | Paste 4,001 characters into composer. | Character counter turns red; send button disabled or server returns `400 message_too_long`. |

### 2.2 Media Recording, Playback & Previews
| # | Scenario | Steps to Execute | Expected Result |
|---|---|---|---|
| 10 | Voice Note Recording | Tap and hold voice note button; record for 15 seconds. | Microphone permission prompt appears; live timer ticks; releasing opens preview with play/pause/cancel/send. |
| 11 | Voice Recording Cutoff | Record continuously for 300 seconds. | Recording stops automatically at 05:00 (300s); file encoded as 16 kHz mono WAV (\(\approx 9.15\text{ MiB}\)). |
| 12 | Video Player | Tap video thumbnail in timeline. | First-frame preview replaces with inline player; play/pause and scrubber operate smoothly; fullscreen toggle works. |
| 13 | Image Fullscreen & Zoom | Tap an inline image. | Opens fullscreen interactive viewer; pinch-to-zoom and pan function; save, copy, and share actions work. |
| 14 | Clipboard Copy | In image viewer, tap "نسخ إلى الحافظة". | Image is copied to OS clipboard via `super_clipboard`; pasting into external app succeeds. |
| 15 | Corrupt / Unsupported File | Upload an unknown binary format (`sample.xyz`). | Timeline displays structured document card with filename, size, and download button. Timeline does not crash. |

### 2.3 Collaboration, Synchronization & Permissions
| # | Scenario | Steps to Execute | Expected Result |
|---|---|---|---|
| 16 | Message Reply | Swipe on a message or choose "رد". | Composer displays quoted parent preview; sent message references `replyToMessageId`; tapping quote scrolls to parent. |
| 17 | Emoji Reaction Toggle | Tap reaction button and select 👍; tap 👍 again. | First tap adds 👍 reaction. Second tap removes 👍 reaction. Exactly one reaction per user per message. |
| 18 | Message Forwarding | Forward a message with attachments to another channel where user is a member. | Target channel receives message with destination-scoped attachment references. |
| 19 | Unauthorized Forwarding | Attempt to forward to a channel where user is not a member. | Action blocked on client; server returns `403 forbidden` if bypassed. |
| 20 | Edit Message (14 min) | At 14m00s after send, sender edits typo in message. | Message updates with edited indicator; `revision` increments; previous text stored in `/audit`. |
| 21 | Edit Message (16 min) | At 16m00s after send, sender attempts to edit message. | Edit option disabled; server rejects with `403 edit_window_expired`. |
| 22 | Delete Message | At 5m00s after send, sender deletes message. | Message text replaced by tombstone `تم حذف هذه الرسالة`; original text archived for HR audit. |
| 23 | Foreground Read Tracking | Receive 10 new messages while channel is in background; then open channel. | Read receipt is sent only when channel route becomes active foreground and messages render on screen. |
| 24 | Incremental Sync Cursor | Post message from Client A; verify Client B received via sync. | Client B polls `/changes?after={cursor}` every 3s, fetches only changed row, updates timeline without reloading full history. |
| 25 | SSRF Link Preview Filter | Paste link `http://169.254.169.254/latest/meta-data/` into composer. | Server preview rejects request as private IP; client leaves plain clickable link without crashing. |

### 2.4 Custom Channel Requests & HR Review Queue
| # | Scenario | Steps to Execute | Expected Result |
|---|---|---|---|
| 26 | Submit Channel Request | `EMP-TEST-01` submits request with name, reason, and 2 colleagues. | Request created in `pending` state; visible under "طلباتي" for employee and "طلبات القنوات" for HR. |
| 27 | Minimum Member Boundary | Submit request with 0 colleagues selected (requester only). | Form validation prevents submission; requires at least 2 members total. |
| 28 | HR Review & Adjust Name | `HR-TEST-01` opens request, changes channel name, adds a member, and approves. | Status becomes `approved`; channel is created atomically; linked `conversationId` is populated; members receive notifications. |
| 29 | Concurrent Approval Race | Two HR admins approve the same request simultaneously. | Exactly one channel created; second approval reuses created channel without creating duplicate. |
| 30 | HR Rejection with Reason | `HR-TEST-01` rejects request without entering reason (blocked); then enters reason and rejects. | Mandatory reason enforced; status becomes `rejected`; requester sees reason. |
| 31 | Nonmember HR Inspection | `HR-TEST-01` opens approved custom channel where they are not a member. | Channel opens in read-only mode with clear banner: "عرض إداري — HR (قراءة فقط)"; composer disabled; does not mark messages read. |

---

## 3. Parity & Rollback Procedures

### 3.1 Parity Check
Before flipping `conversations_rich_chat_v1` on for general users:
1. Open legacy channel in legacy mode and rich mode on identical accounts.
2. Verify department channel history matches exactly.
3. Verify legacy messages and sender names display consistently.

### 3.2 Rollback Procedure
If an unrecoverable defect is detected in production:
1. **Immediate Server Flag Flip**: Update `PHASE007_FEATURE_FLAGS_JSON` on Hostinger to set `conversations_rich_chat_v1: false`.
2. **Client Instant Fallback**: Upon next navigation or app refresh, [`RichConversationEntry`](file:///Users/seg/Shemais/Shemais/zawolf_hr/lib/navigation/rich_conversation_entry.dart) detects `enabled: false` via `GET /capabilities` and renders the legacy [`ConversationEntry`](file:///Users/seg/Shemais/Shemais/zawolf_hr/lib/navigation/conversation_entry.dart).
3. **Data Preservation**: No messages, outbox operations, or local Drift database files are deleted during rollback. Any messages sent during the rich chat period remain intact in Firestore and readable via legacy endpoints.

---

## 4. Required Command Verification

```bash
# Static analysis
flutter analyze

# Architectural layer and query guard tests
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart

# Feature-specific tests
flutter test test/features/conversations/

# Full client and server test suites
flutter test
(cd scripts && npm test)
```
