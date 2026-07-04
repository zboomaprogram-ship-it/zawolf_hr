# Secure CSV Export Guide

ZaWolf HR no longer embeds a Google Service Account private key in the Flutter app. Mobile APKs and PWAs can be inspected by users, so any key bundled as an asset must be treated as exposed.

## Current Export Flow

1. Open **Reports / التقارير** from the HR dashboard.
2. Choose the target month.
3. Tap the report export button.
4. The app generates CSV text locally and copies it to the clipboard.
5. Open Google Sheets and paste the CSV into the first cell.

## Future Direct Google Sheets Export

If direct Sheets writing is required later, add a trusted backend/proxy that stores the service-account key outside the client app. The Flutter client should send a scoped export request to that backend, not hold or load the private key itself.
