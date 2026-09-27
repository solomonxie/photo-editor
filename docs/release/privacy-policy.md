# Privacy Policy — Photo Editor

_Last updated: 2026-09-27_

Photo Editor does not collect, transmit, or store your personal data on any server we control. We operate no server, and there is no account to create.

## What the app stores
Copies of the photos you open, your edits, and your settings are kept in the app's own storage on your device. They stay there until you delete an edit or the app.

## Photos access
Photos are chosen with the system photo picker, so the app never sees the rest of your library. Saving asks for **add-only** access: the app can add a new photo to your library but cannot read it. Location data in a saved photo is kept or removed according to the setting in Settings → Export.

The optional **Compress** tool asks for read/write access to your library, and only when you use it. It reads the photos and videos you choose, adds smaller copies (keeping their date and location), and deletes originals only when you tap Delete and confirm the iOS prompt. Nothing it reads leaves your device.

## On-device processing
Filters, adjustments, crop, skin smoothing, blemish healing, red-eye correction, face and body reshaping, text, stickers and background cutout all run on your iPhone using Apple's Core Image, Metal and Vision frameworks. Face and body landmarks are detected only to place those edits, are held in memory while the photo is open, and are never stored or sent anywhere.

## What leaves your device, and only if you ask
- **AI features** (Magic Erase, Fill, Restyle) — off until you add an API key of your own from OpenAI or Google Gemini. When you tap Erase, Fill or Restyle, a copy of the photo (scaled to at most 1536 pixels), the area you painted and your prompt are sent directly to that provider under your own account with them. Their privacy policy governs that data, and they bill you directly. Your key is stored in the iOS Keychain on this device only; it is never synced to iCloud Keychain, never included in backups, and never sent to us.
- **Sharing and saving** — photos you save to your library or share through the share sheet go where you send them.

No part of this passes through us. There is no intermediary service.

## Analytics and advertising
None. No analytics SDK, no crash reporting, no advertising identifiers, no tracking across apps or websites.

## Children
The app is not directed at children and collects no data from anyone.

## Deleting your data
Delete a single edit from the Home screen, or all of them in Settings → Storage. Deleting the app removes everything it stored. Photos you saved to your library remain there.

## Changes
Material changes to this policy will be published here with a new date.

## Contact
Questions or requests: https://github.com/solomonxie/photo-editor/issues
