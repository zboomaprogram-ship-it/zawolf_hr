# Tasks: Shared Employee Profile Images

**Status:** Approved — implementation in progress

- [ ] Define profile-image domain entity, versioned descriptor, repository contract, and safe error taxonomy.
- [x] Add a reusable presentation-safe `EmployeeAvatar` with image, loading, error, and initials fallback states.
- [x] Add self-service image picker/upload/replace/delete UI to profile settings in Arabic RTL and web/mobile layouts.
- [ ] Add Hostinger profile-media endpoints with idempotent allocate/chunk/finalize/delete/read behavior.
- [ ] Configure a dedicated Google Drive folder and server-only credential/config reference; do not use Firebase Storage.
- [ ] Validate MIME signatures, decoded images, dimensions, orientation, source/rendition limits, and opaque provider metadata.
- [ ] Add server-generated thumbnail/display renditions and atomic profile pointer/version update.
- [ ] Implement authenticated thumbnail/display cache with LRU/TTL, offline fallback, logout cleanup, and revalidation by version.
- [ ] Integrate the shared avatar into profile/web shell, conversations, HR employee management, manager/team/productivity, requests/tasks/reports.
- [ ] Preserve virtual-office character customization as an independent feature and define precedence/fallback behavior.
- [ ] Add narrowly scoped Firestore rules and tests; prepare a rollback-safe production rules deployment for explicit owner approval.
- [ ] Add unit/widget/Node authorization, retry, malformed image, visibility, and cache-eviction coverage.
- [ ] Run `flutter analyze`, architecture/query guards, `flutter test`, and `(cd scripts && npm test)`.
