# Privacy Policy — Photo Editor

_Last updated: 2026-10-02_

Photo Editor does not collect, transmit, or store your personal data on any server we control. We operate no server, and there is no account to create.

## What the app stores
Copies of the photos you open, your edits, and your settings are kept in the app's own storage on your device. Demo mode's sample edits are kept in a separate folder there too. They stay there until you delete an edit or the app.

## Photos access
Photos you edit are chosen with the system photo picker, which shares only the photo you pick. Exporting to Photos asks for **add-only** access: the app can add a new photo to your library but cannot read it. Location data in an exported photo is kept or removed according to the setting in Settings → Export.

The optional **Compress** tool asks for read/write access to your library, and only when you use it. It reads the photos and videos you choose, adds smaller copies (keeping their date and location), and deletes originals only when you tap Delete and confirm the iOS prompt. Nothing it reads leaves your device.

## On-device processing
Beauty touch-ups (skin smoothing, whitening, blemish healing, red-eye and the rest), face and body reshaping, background cutout, export and Compress all run on your iPhone using Apple's Core Image, Metal, Vision and AVFoundation frameworks. The app bundles no third-party AI models. Face and body landmarks are detected only to place those edits, are held in memory while the photo is open, and are never stored or sent anywhere.

## What leaves your device, and only if you ask
- **AI features** (Magic Erase, Fill, Restyle, and Hair: hair, beards, hair colour) — off until you add an API key of your own from OpenAI or Google Gemini. When you tap Erase, Fill, Restyle or Hair's Apply, a copy of the photo (scaled to at most 1536 pixels), the area you painted or the app placed on the face you chose, and the prompt are sent directly to that provider under your own account with them. Their privacy policy governs that data, and they bill you directly. Your key is stored in the iOS Keychain on this device only; it is never synced to iCloud Keychain, never included in backups, and never sent to us.
- **Sharing and exporting** — photos you export to your library or share through the share sheet go where you send them.

No part of this passes through us. There is no intermediary service.

## Analytics and advertising
None. No analytics SDK, no crash reporting, no advertising identifiers, no tracking across apps or websites.

## Children
The app is not directed at children and collects no data from anyone.

## Deleting your data
Delete a single edit from the Home screen, or all of them in Settings → Storage. Deleting the app removes everything it stored. Photos you exported to your library remain there.

## Changes
Material changes to this policy will be published here with a new date.

## Contact
Questions or requests: https://github.com/solomonxie/photo-editor/issues
