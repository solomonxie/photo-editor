# Photo Editor

A free iPhone photo editor in the spirit of Meitu, without the subscription.
Everything except generative AI runs on the device. No crop, filters, basic
adjustments or text: the Photos app already does those. Only the edits it can't.

- **Cutout:** remove, blur or recolour the background, or lift the subject into a sticker.
- **Retouch:** smooth skin, tap-to-heal blemishes, red eye.
- **Reshape:**
  - Face: slim, chin, eyes, nose, forehead.
  - Body: waist, hips, chest, legs, shoulders, arms.
  - Manual push, grow and shrink brush.
- **Hair, on your AI key:** add hair, thicken, bangs, beards, mustache and hair colour,
  masked automatically on the face you tap.
- **AI, on your own key (OpenAI or Gemini):** Magic Erase, Fill (e.g. "fuller hair")
  and Restyle. The key stays in this iPhone's Keychain, and your vendor bills you.
- **Save vs Export:** Save keeps the edit in the app, still adjustable. Export writes a new
  photo to the library; the original is never touched.
- **Save space:** export at HD–4K with a quality level and a live size estimate, and
  Compress library photos and videos into smaller HEIC/HEVC copies.

## Setup

```
cp Config/Local.xcconfig.example Config/Local.xcconfig   # add your Team ID
xcodegen generate && open PhotoEditor.xcodeproj
```

`make help` lists the rest: `make ios` (Release build onto the paired iPhone), `make test`
(unit tests and the 48 MP benchmark on the device), `make release` (archive and upload).

Design, UI and build plan: [`docs/design/photo-editor`](docs/design/photo-editor/).
App Store release checklist: [`docs/release`](docs/release/).
