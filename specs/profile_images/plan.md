# Implementation Plan: Shared Employee Profile Images

**Status:** Approved — implementation in progress  
**Spec:** [spec.md](spec.md)

## Slice 1 — Domain and identity UI

1. Add `lib/features/profile_images/` with a domain `ProfileImage` entity, repository contract, and focused upload/cache Cubits.
2. Add a presentation-safe `EmployeeAvatar` component that accepts a profile-image descriptor, name, size, and fallback initials. It must not import Firebase, Drive, or HTTP.
3. Replace visible identity avatars incrementally: current profile and web shell first, then chat, HR employee management, manager/team/productivity, requests/tasks/reports.
4. Keep `avatarFaceUrl` limited to the virtual-office character; ordinary surfaces prefer `ProfileImage` then legacy `photoURL` then initials.

## Slice 2 — Hostinger governed media adapter

1. Build authenticated profile-media allocate/chunk/finalize/delete/read endpoints beside the conversation media routes, sharing only the provider abstraction.
2. Use a distinct Drive folder configuration and separate Firestore metadata (`profileImages`) and provider-secret records (`workspaceResourceSecrets`) with opaque IDs.
3. Validate operation IDs, ownership, MIME signatures, decoded image dimensions, byte ceilings, and fixed thumbnail/display renditions.
4. Atomically advance the user document descriptor/version only after both renditions are finalized; retain idempotent receipts and safe failures.

## Slice 3 — Client upload and cache

1. Add profile settings picker, crop/preview, upload state, retry, replacement, and deletion.
2. Persist an upload intent until a terminal receipt; resume safely after navigation/relaunch.
3. Cache thumbnails by authenticated user and descriptor version with a bounded LRU/TTL; clear on logout or identity change.
4. Read display bytes only on a full profile view; list rows use thumbnails.

## Slice 4 — Authorization, migration, and rollout

1. Add narrow Firestore rules for profile-image metadata and pointer updates; preserve current user visibility rules for reads.
2. Migrate only on demand: map a valid legacy `photoURL` as a temporary fallback, never bulk-copy data URLs or provider links.
3. Add authorized HR override only if required; audit it separately from employee self-service.
4. Test employee/manager/HR visibility, upload/retry/delete, stale image version, offline fallback, and host/provider failures.
5. Produce a Hostinger deployment artifact and an explicit Firestore rules rollout/rollback command for owner approval.
