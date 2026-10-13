# Quickstart & Verification: Chat Performance & Assets

## Production Storage Setup

Apply the checked-in browser CORS policy once before validating direct uploads
from Flutter web:

```bash
gcloud storage buckets update \
  gs://zawolf-hr-system-60317.firebasestorage.app \
  --cors-file=scripts/firebase-storage-cors.json
```

The Firebase Admin service account must retain `Storage Object Admin` for this
bucket. Android and iOS direct uploads do not depend on browser CORS. If a
browser cannot reach the resumable session, the client resumes through the
authenticated Hostinger proxy.

## 1. Local Testing & Verification

### Run Flutter Characterization & Architecture Tests
```bash
flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
flutter test test/features/conversations/
```

### Run Node.js Contract Tests
```bash
(cd scripts && npm test test/rich-conversations.test.js)
```

---

## 2. Manual Verification Checklist

1. **Composer Typing Performance**:
   - Open a chat channel on mobile or Chrome web.
   - Attach 3 large images (3–10 MB each).
   - Rapidly type a paragraph of Arabic and English text.
   - Verify zero frame drops or keyboard lag.
2. **Offline Draft Recovery**:
   - Attach files and enter draft text.
   - Kill the application immediately.
   - Relaunch the application and return to the channel.
   - Verify the draft text and staged attachments restore completely from the local filesystem cache.
3. **Upload Acceleration**:
   - Upload a 10 MB image.
   - Check network inspector: verify client-side compression reduces the upload to < 1 MB and direct GCS resumable upload transfers the file in one 4 MiB chunk.
   - Confirm upload completes in < 2 seconds.
4. **Instant Timeline Thumbnail Preview**:
   - Send the image.
   - Inspect the receiver screen: verify the micro-thumbnail appears instantaneously (< 200 ms) before the full image finishes downloading.
