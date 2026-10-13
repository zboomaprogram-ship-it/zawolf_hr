# Implementation Plan: Chat Performance & High-Speed Asset Pipeline

**Branch**: `018-chat-performance-assets` | **Date**: 2026-10-13 | **Spec**: [specs/018-chat-performance-assets/spec.md](file:///Users/seg/Shemais/Shemais/zawolf_hr/specs/018-chat-performance-assets/spec.md)

**Input**: Feature specification from `/specs/018-chat-performance-assets/spec.md`

---

## Summary

The chat subsystem currently experiences UI lag during composer drafting and high upload/download latencies for media attachments due to:
1. Inefficient SQLite storage of raw binary BLOBs (`chat_blob_rows`).
2. Immediate, un-debounced draft re-serialization on every keystroke.
3. Double-hop proxying of 1 MiB chunks through Hostinger Node.js to Google Cloud Storage.
4. Lack of client-side pre-compression and progressive micro-thumbnails.

This implementation executes a zero-downtime, Strangler Fig performance migration:
- **Phase 1 (Client & Local Store)**: Debounce `ChatComposerCubit` drafting; offload binary blobs from Drift/SQLite to sandboxed device filesystem storage; integrate client-side image compression and micro-thumbnail generation.
- **Phase 2 (Cloud Pipeline & Direct Uploads)**: Add direct Google Cloud Storage Resumable Upload session generation to the `/conversations/v2` API, increase chunk size to 4 MiB, provide transparent fallback to server proxying, and implement direct CDN-cached downloads.

---

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x (Frontend), Node.js 18+ / CommonJS (Backend).
**Primary Dependencies**: `flutter_bloc`, `drift`, `path_provider`, `image` / `image_picker`, `file_picker`, `@google-cloud/storage`, `firebase-admin`.
**Storage**: Local sandboxed filesystem cache (`chat_files/`) or browser Cache Storage + Drift SQLite for metadata; Google Cloud Storage (bucket `${projectId}.firebasestorage.app`, production `zawolf-hr-system-60317.firebasestorage.app`, prefix `conversation-media/`) for cloud storage.
**Testing**: `flutter test`, `test/architecture_guard_test.dart`, `scripts/test/rich-conversations.test.js`.
**Target Platform**: Mobile (Android, iOS) & Desktop Web (Chrome, Safari, Edge).
**Project Type**: Mobile App / Web App + Integration Microservice (Hostinger Node.js).
**Performance Goals**:
- 60 fps / < 16 ms composer input latency with 10 attachments staged.
- 5 MB image upload time reduced from ~7s to < 1.5s on 20 Mbps connections.
- Instant (< 200 ms) timeline thumbnail display for incoming images.
- SQLite DB file size stable under 15 MB.
**Constraints**:
- Max file upload limit: 25 MB per file.
- Persistent local media cache budget: 256 MB LRU.
- Strict backward compatibility with legacy Google Drive / server-proxied attachment records.
**Scale/Scope**: All company employees active across 1:1 direct chats and department channels.

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / Rule | Compliance Status | Analysis & Verification |
| :--- | :--- | :--- |
| **I. Strangler Fig Delivery** | **PASS** | Existing `/conversations/v2/channels/{id}/uploads` proxy endpoints remain functional. Direct GCS upload is added as a capability; client automatically falls back to proxying if GCS is unreachable. |
| **II. Enforced Layer Boundaries** | **PASS** | Presentation (`ChatComposerCubit`, `RichAttachmentView`) relies strictly on Domain contracts (`ChatDraftFile`, `RichAttachment`, `ChatMediaGateway`). Filesystem operations and Drift changes remain encapsulated in Data layer (`chat_store.dart`, `chat_media_gateway_impl.dart`). |
| **III. Focused Cubits** | **PASS** | `ChatComposerCubit` remains under 250 lines and handles only composer UI state (debouncing draft writes via repository). Persistence and file I/O remain outside the Cubit. |
| **IV. Critical Payroll & Attendance** | **PASS** | No payroll or attendance state/logic is modified. |
| **V. Spec-Driven, Test-First Delivery** | **PASS** | Spec written (`spec.md`), planning documented (`plan.md`, `research.md`, `data-model.md`), contract tests characterized before changes. Owner review gate strictly enforced before implementation. |

---

## Project Structure

### Documentation (this feature)

```text
specs/018-chat-performance-assets/
├── spec.md              # Feature specification
├── plan.md              # Implementation plan (this file)
├── research.md          # ADRs & research on compression, direct GCS, and local filesystem caching
├── data-model.md        # Entities, schema changes, and Drift repository models
├── quickstart.md        # Verification and developer test instructions
├── checklists/
│   └── requirements.md  # Spec requirements checklist
└── contracts/
    └── direct-upload.md # API contract for direct resumable uploads and thumbnail payloads
```

### Source Code Impact

```text
lib/features/conversations/
├── data/
│   ├── local/
│   │   ├── chat_database.dart             # Retain legacy/web Blob rows during compatibility window
│   │   ├── chat_blob_store.dart           # Binary storage boundary
│   │   └── chat_store.dart                # Native filesystem plus lazy legacy-blob migration
│   ├── media/
│   │   └── chat_media_gateway_impl.dart   # Background image compression & micro-thumbnail generation
│   ├── chat_transport.dart                # Support direct GCS PUT chunks alongside proxy transport
│   └── rich_chat_repository_impl.dart     # Direct upload orchestration with fallback; 4 MiB chunking
├── domain/
│   ├── entities/rich_chat.dart            # Add thumbnailBase64 and directUploadUrl fields
│   └── repositories/rich_chat_repository.dart
└── presentation/
    ├── cubit/chat_composer_cubit.dart     # Debounce saveDraft (800ms); avoid rewriting file blobs
    └── widgets/rich_attachment_view.dart  # Render micro-thumbnail immediately while full file downloads

scripts/conversations/
├── uploads.js                             # Support issuing direct GCS Resumable Upload session URIs
├── firebase-storage-media-provider.js     # Expose direct resumable session URI with CORS origin
└── router.js                              # Route direct upload finalize and metadata validation
```

---

## Complexity Tracking

*No constitutional violations. All architecture rules strictly satisfied.*
