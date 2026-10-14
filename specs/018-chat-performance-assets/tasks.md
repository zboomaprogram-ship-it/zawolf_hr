# Tasks: Chat Performance & High-Speed Asset Pipeline

**Input**: Design documents from `/specs/018-chat-performance-assets/`
**Prerequisites**: [spec.md](file:///Users/seg/Shemais/Shemais/zawolf_hr/specs/018-chat-performance-assets/spec.md), [plan.md](file:///Users/seg/Shemais/Shemais/zawolf_hr/specs/018-chat-performance-assets/plan.md), [research.md](file:///Users/seg/Shemais/Shemais/zawolf_hr/specs/018-chat-performance-assets/research.md), [data-model.md](file:///Users/seg/Shemais/Shemais/zawolf_hr/specs/018-chat-performance-assets/data-model.md), [contracts/direct-upload.md](file:///Users/seg/Shemais/Shemais/zawolf_hr/specs/018-chat-performance-assets/contracts/direct-upload.md)

---

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story mapping (`US1`, `US2`, `US3`, `US4`)

---

## Phase 1: Setup & Characterization

**Purpose**: Characterize existing behavior with baseline tests before making architectural changes.

- [X] T001 Characterize existing composer draft persistence and outbox behavior with tests in `test/features/conversations/chat_composer_cubit_test.dart`.
- [X] T002 Characterize existing upload initialization and proxied chunk handling in `scripts/test/conversation-media.test.js` and `test/features/conversations/rich_chat_repository_test.dart`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create shared filesystem cache infrastructure before modifying database and cubits.

- [X] T003 Create the `ChatBlobStore` boundary and native sandboxed filesystem adapter in `lib/features/conversations/data/local/` with an actor-wide 256 MB media budget enforced by the repository metadata index.
- [X] T004 [P] Add unit tests for native file write, replacement, actor isolation, and removal in `test/features/conversations/chat_blob_store_test.dart`.

---

## Phase 3: User Story 1 - Smooth Composer Typing & Filesystem Blob Offloading (Priority: P1) 🎯 MVP

**Goal**: Eliminate typing stutter by debouncing draft saves and storing attachment blobs on the filesystem instead of SQLite.

**Independent Test**: Stage 3 large attachments (> 5 MB), type rapidly in composer, and verify zero SQLite BLOB writes occur during keystrokes and typing latency stays under 16 ms.

- [X] T005 [US1] Debounce draft persistence in `lib/features/conversations/presentation/cubit/chat_composer_cubit.dart` by 800 ms so typing body text never blocks on disk I/O.
- [X] T006 [US1] Update `RichChatRepositoryImpl.saveDraft` in `lib/features/conversations/data/rich_chat_repository_impl.dart` to update only the body metadata row without re-serializing or duplicating existing attachment files on disk.
- [X] T007 [US1] Refactor `lib/features/conversations/data/local/chat_store.dart` to delegate `blob()` and `bytes()` to the native `ChatBlobStore` filesystem adapter rather than inserting new native payloads into `chat_blob_rows`.
- [X] T008 [US1] Retain `ChatBlobRows` only as a web/compatibility fallback and lazily migrate native legacy rows to sandboxed files on first access.
- [X] T009 [US1] Verify draft recovery on app restart and verify zero SQLite BLOB writes during continuous typing with tests in `test/features/conversations/chat_composer_cubit_test.dart`.

---

## Phase 4: User Story 2 - Instant Client-Side Image Pre-Compression & Micro-Thumbnails (Priority: P1)

**Goal**: Automatically compress images to < 800 KB and embed inline micro-thumbnails for instant visual rendering.

**Independent Test**: Pick an 8 MB camera photo, verify compression reduces it to < 800 KB within 150 ms, and verify receiver timeline displays the blurred thumbnail in < 200 ms.

- [X] T010 [P] [US2] Implement fast client-side image pre-compression (max 1920px, WebP/JPEG 80%, strip heavy EXIF) in `lib/features/conversations/data/media/chat_media_gateway_impl.dart`.
- [X] T011 [P] [US2] Implement micro-thumbnail generator ($120 \times 120$ px, < 10 KB, Base64 encoded) in `lib/features/conversations/data/media/chat_media_gateway_impl.dart`.
- [X] T012 [US2] Update `ChatDraftFile` and `RichAttachment` entities in `lib/features/conversations/domain/entities/rich_chat.dart` and codecs in `lib/features/conversations/data/chat_codec.dart` to support `thumbnailBase64`.
- [X] T013 [US2] Update `RichAttachmentView` in `lib/features/conversations/presentation/widgets/rich_attachment_view.dart` to immediately render the embedded `thumbnailBase64` as a low-resolution preview while the full asset loads.
- [X] T014 [US2] Add unit tests for image compression and micro-thumbnail decoding in `test/features/conversations/chat_media_gateway_test.dart`.

---

## Phase 5: User Story 3 - High-Speed Direct Cloud Uploads (Priority: P2)

**Goal**: Upload 4 MiB chunks directly to Google Cloud Storage Resumable Upload session URIs with transparent proxy fallback.

**Independent Test**: Upload a 20 MB video, verify direct GCS transfer at 4 MiB chunk intervals, and verify automatic fallback to Hostinger proxy if direct GCS upload fails.

- [X] T015 [US3] Update backend upload initialization in `scripts/conversations/uploads.js` and `scripts/conversations/firebase-storage-media-provider.js` to return a direct GCS Resumable Upload session URI with appropriate CORS headers.
- [X] T016 [P] [US3] Add backend contract tests for direct upload session initialization and finalize in `scripts/test/conversation-media.test.js` and direct client fallback tests.
- [X] T017 [US3] Update `ChatTransport` and `RichChatRepositoryImpl._upload` in `lib/features/conversations/data/rich_chat_repository_impl.dart` to upload 4 MiB chunks directly to `sessionUri`.
- [X] T018 [US3] Implement automatic fallback in `RichChatRepositoryImpl` to switch to server-proxied chunk upload if direct cloud upload encounters network errors.
- [X] T019 [US3] Add unit and integration tests for direct cloud upload and fallback in `test/features/conversations/rich_chat_repository_test.dart`.

---

## Phase 6: User Story 4 - Filesystem Media Cache & Direct CDN Downloads (Priority: P2)

**Goal**: Stream media directly to the filesystem cache and utilize HTTP caching headers to avoid redundant downloads.

**Independent Test**: Download an attachment, verify it is saved in `chat_cache/`, restart offline, and confirm the attachment opens immediately from local disk cache.

- [X] T020 [US4] Update `download()` in `RichChatRepositoryImpl` to store downloaded bytes through the native `ChatBlobStore` and enforce one actor-wide 256 MB LRU budget.
- [X] T021 [US4] Add immutable cache-control headers (`Cache-Control: private, max-age=604800, immutable`) to download responses in `scripts/conversations/uploads.js`.
- [X] T022 [US4] Add tests for offline media loading from filesystem cache in `test/features/conversations/rich_chat_repository_test.dart` and `test/features/conversations/chat_blob_store_test.dart`.

---

## Phase 7: Polish & Architecture Guard

**Purpose**: Enforce quality gates across all tests, linters, and architecture boundaries.

- [X] T023 Run `flutter analyze` and ensure zero analysis warnings across modified features.
- [X] T024 Run architecture guard tests `flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart`.
- [X] T025 Run full backend test suite `(cd scripts && npm test)` and verify all Node.js tests pass.
- [X] T026 Make message persistence independent from recipient notification fan-out by queuing bounded explicit recipients in `conversationNotificationOutbox`.
- [X] T027 Show gallery selections immediately after the native picker returns and accept iPhone HEIC assets in server-side media validation.
