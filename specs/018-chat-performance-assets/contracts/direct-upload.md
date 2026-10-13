# API Contracts: Direct Resumable Cloud Upload & Attachments

## 1. Initiate Upload Session
### `POST /conversations/v2/channels/{channelId}/uploads`

**Request Body**:
```json
{
  "operationId": "op-491a-821f",
  "fileName": "site_photo.jpg",
  "mimeType": "image/jpeg",
  "sizeBytes": 782410,
  "kind": "image",
  "thumbnailBase64": "data:image/webp;base64,UklGR...",
  "durationSeconds": null
}
```

**Response (200 OK)**:
```json
{
  "ok": true,
  "resourceId": "chat:b1839f28...",
  "offset": 0,
  "status": "pending",
  "direct": true,
  "sessionUri": "https://storage.googleapis.com/upload/storage/v1/b/zawolf-hr-system-60317.firebasestorage.app/o?uploadType=resumable&upload_id=ADPycd...",
  "chunkSize": 4194304
}
```

---

## 2. Direct Chunk Upload
### `PUT {sessionUri}` (Direct to Google Cloud Storage)

**Headers**:
- `Content-Length`: `{chunkBytes}`
- `Content-Range`: `bytes {offset}-{offset + chunkBytes - 1}/{totalBytes}`

**Response (308 Resume Incomplete)**:
```text
Range: bytes=0-4194303
```

**Response (200 / 201 OK)**: Upload completed.

---

## 3. Finalize Upload
### `POST /conversations/v2/channels/{channelId}/uploads/{resourceId}/finalize`

**Response (200 OK)**:
```json
{
  "ok": true,
  "resourceId": "chat:b1839f28...",
  "offset": 782410,
  "status": "uploaded",
  "attachment": {
    "resourceId": "chat:b1839f28...",
    "fileName": "site_photo.jpg",
    "mimeType": "image/jpeg",
    "sizeBytes": 782410,
    "kind": "image",
    "thumbnailBase64": "data:image/webp;base64,UklGR...",
    "status": "uploaded"
  }
}
```
