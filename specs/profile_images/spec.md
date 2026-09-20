# Feature Specification: Shared Employee Profile Images

**Status:** Approved — implementation in progress  
**Feature boundary:** `lib/features/profile_images/`, user profile composition, employee/manager/productivity/chat presentation adapters, Hostinger media runtime, Firestore rules, and `specs/017-profile-images/`.

## Goal

Let every active employee choose one professional profile image that appears consistently wherever their identity is shown: their profile, conversations, employee management, attendance/productivity, tasks, approvals, reports, and web navigation.

## Current state

`users.photoURL` exists but the normal profile screen only renders it. The virtual-office avatar separately stores `avatarFaceUrl` as a Firestore data URL. Chat and most management screens render initials because their identity DTOs do not include a shared image descriptor. The current data-URL approach is unsuitable as the company-wide photo source because it duplicates image bytes into user documents and cannot provide governed caching, replacement, or deletion.

## User stories

### P0 — Choose and update my photo

An authenticated employee can select a JPG, PNG, WebP, or HEIC photo from the gallery or files, sees a crop/preview, and saves it as their profile image. The updated image appears throughout the app after a refresh without changing their name, role, or avatar customization.

**Acceptance criteria**

- The client accepts only image formats, validates decoded image data, normalizes orientation, crops to square, and produces a bounded thumbnail plus a display rendition.
- Upload progress, offline failure, retry, replacement, and deletion are clear in Arabic RTL.
- Replacing or deleting a photo changes only that employee’s current profile-image pointer; historical audit entries retain no image bytes.
- The employee can continue using the existing virtual-office avatar independently. The profile photo takes precedence in ordinary identity surfaces; the avatar is used only where the virtual office needs it.

### P0 — One identity image everywhere

Identity components use one `ProfileImage` descriptor and safe fallback initials. It is rendered in employee profile, rich chat inbox/messages/member list/direct picker, HR employee management, manager/team screens, productivity/performance screens, request and task participants, payroll/report participant rows, and web-shell/profile controls.

**Acceptance criteria**

- An unavailable, revoked, deleted, malformed, or expired image falls back to initials without breaking the screen.
- List views use thumbnails and bounded caching. Full-size bytes are requested only on a full profile view.
- Chat message history never copies raw image bytes into message documents; sender identity resolves from the current authorized user profile.
- Role and organization visibility rules remain unchanged. A photo never makes an employee directory entry readable to a user who cannot read that employee today.

### P0 — Governed media without Firebase Storage

Profile media uses the existing Hostinger-managed Google Drive OAuth provider, in a dedicated profile-media folder and Firestore metadata/secrets split. Firebase Storage is not used.

**Acceptance criteria**

- The public user document contains only a stable opaque profile-image descriptor/version; provider IDs and OAuth details remain server-side.
- Hostinger validates ownership, content type, image dimensions, byte limit, upload operation ID, and image decoding before finalizing a replacement.
- Read/download endpoints authorize the requesting user against the same existing user-profile visibility rules before returning the rendition.
- Server storage failures return safe Arabic recovery codes and do not leave a partially updated `photoURL` pointer.
- The Drive folder and credential configuration are distinct from conversation attachments, so cleanup and quota diagnostics are attributable.

### P1 — Performance, privacy, and lifecycle

- Store square 96px thumbnail and 512px display renditions; each source photo is capped at 5 MB before client processing and each derived rendition is capped at 500 KB.
- Cache thumbnails per authenticated user with LRU/TTL, clear them on logout/account switch, and revalidate when the image version changes.
- A user can remove their own image. HR may only replace an image through an explicit, audited employee-management action if that permission is approved in the existing role model.
- Audit upload, replace, delete, and HR override without provider URLs or image bytes.

## Non-goals

- Firebase Storage.
- Face recognition, automatic moderation decisions, public URLs, image search, or copying photos into chat messages.
- Replacing the virtual-office character customizer.

## Security and rollout

- Additive Firestore metadata and Hostinger routes only; no destructive migration.
- Firestore rules require explicit owner/HR authorization and constrain descriptor fields. Production rules deployment requires owner approval and a rollback plan.
- Existing `photoURL` values and `avatarFaceUrl` remain readable during migration. New surfaces prefer the governed profile descriptor, then legacy `photoURL`, then initials.
