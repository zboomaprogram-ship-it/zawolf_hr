# Meeting requests

This migrated slice implements employee meeting requests, recipient decisions,
room availability, and HR room administration. It is delivered under the
reviewed umbrella specification `010-meeting-custom-requests`.

The server is authoritative for room overlap, approval permissions, idempotent
operations, and notification delivery. The Flutter feature has no direct
Firestore writes.
