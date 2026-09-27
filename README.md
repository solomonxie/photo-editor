# Photo Editor

A free iPhone photo editor in the spirit of Meitu, without the subscription.
Everything except generative AI runs on the device.

- **Adjust:** 13 sliders plus Auto.
- **Filters:** 16 looks.
- **Crop:** straighten, rotate, flip and aspect presets.
- **Retouch:** smooth skin, tap-to-heal blemishes, red eye.
- **Reshape:**
  - Face: slim, chin, eyes, nose, forehead.
  - Body: waist, hips, chest, legs, shoulders, arms.
  - Manual push, grow and shrink brush.
- **Text and stickers:** as movable layers.
- **Cutout:** remove, blur or recolour the background, or lift the subject into a sticker.
- **AI, on your own key (OpenAI or Gemini):** Magic Erase, Fill (e.g. "fuller hair")
  and Restyle. The key stays in this iPhone's Keychain, and your vendor bills you.
- **Non-destructive:** every saved edit stays adjustable, and saving always adds a new photo.
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
